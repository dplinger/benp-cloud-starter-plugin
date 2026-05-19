package com.bnep.idea.plugin;

import com.intellij.execution.runners.ExecutionUtil;
import com.intellij.execution.Executor;
import com.intellij.execution.RunManager;
import com.intellij.execution.RunnerAndConfigurationSettings;
import com.intellij.execution.executors.DefaultDebugExecutor;
import com.intellij.execution.ui.RunContentDescriptor;
import com.intellij.execution.ui.RunContentManager;
import com.intellij.openapi.Disposable;
import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.startup.StartupActivity;
import com.intellij.openapi.util.Disposer;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import org.jetbrains.annotations.NotNull;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class BnepCloudPlugin implements StartupActivity, Disposable {

    private static final Logger LOG = Logger.getInstance(BnepCloudPlugin.class);
    private static final Pattern NAME_PATTERN = Pattern.compile("\"name\"\\s*:\\s*\"([^\"]+)\"");
    private static final AtomicBoolean STARTED = new AtomicBoolean(false);

    private final Project project;
    private final int port;
    private HttpServer server;

    public BnepCloudPlugin() {
        this.project = null;
        this.port = 58080;
    }

    private BnepCloudPlugin(Project project, int port) {
        this.project = project;
        this.port = port;
    }

    @Override
    public void runActivity(@NotNull Project project) {
        if (!STARTED.compareAndSet(false, true)) {
            return;
        }
        int port = Integer.parseInt(System.getProperty("bnep.debug.port", "58080"));
        BnepCloudPlugin plugin = new BnepCloudPlugin(project, port);
        plugin.start();
        Disposer.register(project, plugin);
    }

    private void start() {
        try {
            server = HttpServer.create(new InetSocketAddress("127.0.0.1", port), 0);
            server.setExecutor(Executors.newFixedThreadPool(2));
            server.createContext("/health", this::health);
            server.createContext("/configs", this::configs);
            server.createContext("/run", this::run);
            server.createContext("/stop", this::stop);
            server.createContext("/running", this::running);
            server.start();
            LOG.info("BNEP Cloud Plugin HTTP server started on 127.0.0.1:" + port);
        } catch (IOException e) {
            LOG.warn("Failed to start HTTP server: " + e.getMessage());
        }
    }

    @Override
    public void dispose() {
        if (server != null) {
            server.stop(0);
            STARTED.set(false);
        }
    }

    // ---- endpoints ----

    private void health(HttpExchange ex) throws IOException {
        json(ex, 200, "{\"status\":\"ok\"}");
    }

    private void configs(HttpExchange ex) throws IOException {
        if (!"GET".equals(ex.getRequestMethod())) {
            json(ex, 405, "{\"error\":\"method not allowed\"}");
            return;
        }
        String[] result = new String[1];
        ApplicationManager.getApplication().invokeAndWait(() -> {
            StringBuilder sb = new StringBuilder("[");
            boolean first = true;
            for (RunnerAndConfigurationSettings s : RunManager.getInstance(project).getAllSettings()) {
                if (!first) sb.append(",");
                first = false;
                sb.append("{\"name\":\"").append(esc(s.getName()))
                        .append("\",\"type\":\"").append(esc(s.getType().getDisplayName()))
                        .append("\"}");
            }
            sb.append("]");
            result[0] = sb.toString();
        });
        json(ex, 200, result[0]);
    }

    private void run(HttpExchange ex) throws IOException {
        if (!"POST".equals(ex.getRequestMethod())) {
            json(ex, 405, "{\"error\":\"method not allowed\"}");
            return;
        }
        String body = new String(ex.getRequestBody().readAllBytes(), StandardCharsets.UTF_8);
        String name = extractName(body);
        if (name == null) {
            json(ex, 400, "{\"error\":\"missing 'name'\"}");
            return;
        }
        String[] err = new String[1];
        ApplicationManager.getApplication().invokeAndWait(() -> {
            RunnerAndConfigurationSettings settings = RunManager.getInstance(project).findConfigurationByName(name);
            if (settings == null) {
                settings = RunManager.getInstance(project).getAllSettings().stream()
                        .filter(s -> s.getName().equalsIgnoreCase(name))
                        .findFirst().orElse(null);
            }
            if (settings == null) {
                err[0] = "{\"error\":\"configuration not found: " + esc(name) + "\"}";
                return;
            }
            Executor executor = DefaultDebugExecutor.getDebugExecutorInstance();
            ExecutionUtil.runConfiguration(settings, executor);
        });
        if (err[0] != null) {
            json(ex, 404, err[0]);
        } else {
            json(ex, 200, "{\"status\":\"started\",\"name\":\"" + esc(name) + "\"}");
        }
    }

    private void stop(HttpExchange ex) throws IOException {
        if (!"POST".equals(ex.getRequestMethod())) {
            json(ex, 405, "{\"error\":\"method not allowed\"}");
            return;
        }
        String body = new String(ex.getRequestBody().readAllBytes(), StandardCharsets.UTF_8);
        String name = extractName(body);
        if (name == null) {
            json(ex, 400, "{\"error\":\"missing 'name'\"}");
            return;
        }
        String[] err = new String[1];
        ApplicationManager.getApplication().invokeAndWait(() -> {
            RunContentManager mgr = RunContentManager.getInstance(project);
            if (mgr == null) {
                err[0] = "{\"error\":\"no RunContentManager\"}";
                return;
            }
            boolean stopped = false;
            for (RunContentDescriptor d : mgr.getAllDescriptors()) {
                if (d.getDisplayName().equals(name)) {
                    if (d.getProcessHandler() != null) {
                        d.getProcessHandler().destroyProcess();
                        stopped = true;
                    }
                }
            }
            if (!stopped) {
                err[0] = "{\"error\":\"no running process: " + esc(name) + "\"}";
            }
        });
        if (err[0] != null) {
            json(ex, 404, err[0]);
        } else {
            json(ex, 200, "{\"status\":\"stopped\",\"name\":\"" + esc(name) + "\"}");
        }
    }

    private void running(HttpExchange ex) throws IOException {
        if (!"GET".equals(ex.getRequestMethod())) {
            json(ex, 405, "{\"error\":\"method not allowed\"}");
            return;
        }
        String[] result = new String[1];
        ApplicationManager.getApplication().invokeAndWait(() -> {
            RunContentManager mgr = RunContentManager.getInstance(project);
            if (mgr == null) {
                result[0] = "[]";
                return;
            }
            StringBuilder sb = new StringBuilder("[");
            boolean first = true;
            for (RunContentDescriptor d : mgr.getAllDescriptors()) {
                if (d.getProcessHandler() != null && !d.getProcessHandler().isProcessTerminated()) {
                    if (!first) sb.append(",");
                    first = false;
                    sb.append("\"").append(esc(d.getDisplayName())).append("\"");
                }
            }
            sb.append("]");
            result[0] = sb.toString();
        });
        json(ex, 200, result[0]);
    }

    // ---- helpers ----

    private static String extractName(String json) {
        Matcher m = NAME_PATTERN.matcher(json);
        return m.find() ? m.group(1) : null;
    }

    private static String esc(String s) {
        if (s == null) return "";
        return s.replace("\\", "\\\\").replace("\"", "\\\"");
    }

    private static void json(HttpExchange ex, int code, String body) throws IOException {
        ex.getResponseHeaders().set("Content-Type", "application/json; charset=utf-8");
        byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
        ex.sendResponseHeaders(code, bytes.length);
        try (OutputStream os = ex.getResponseBody()) {
            os.write(bytes);
        }
    }
}
