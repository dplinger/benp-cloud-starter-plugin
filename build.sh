#!/usr/bin/env bash
# Build BNEP Cloud Starter IDEA plugin jar
set -e

IDEA_HOME="D:/Java/IntelliJ IDEA 2026.1.1"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$PROJECT_DIR/src/main/java"
OUT_DIR="$PROJECT_DIR/target/classes"
PLUGIN_JAR="$PROJECT_DIR/target/bnep-cloud-starter-plugin.jar"

if [ ! -f "$IDEA_HOME/lib/app.jar" ]; then
    echo "错误: 在 $IDEA_HOME 未找到 IntelliJ IDEA" >&2
    echo "请修改 build.sh 中的 IDEA_HOME 变量" >&2
    exit 1
fi

echo "Using IDEA_HOME: $IDEA_HOME"

rm -rf "$PROJECT_DIR/target"
mkdir -p "$OUT_DIR"

echo "Compiling..."
javac -d "$OUT_DIR" \
    -cp "$IDEA_HOME/lib/*" \
    "$(find "$SRC_DIR" -name '*.java')"

echo "Packaging plugin jar..."
cd "$OUT_DIR" && jar cf "$PLUGIN_JAR" . && cd "$PROJECT_DIR"
cd "$PROJECT_DIR/src/main/resources" && jar uf "$PLUGIN_JAR" META-INF/plugin.xml && cd "$PROJECT_DIR"

mkdir -p "$PROJECT_DIR/dist"
cp "$PLUGIN_JAR" "$PROJECT_DIR/dist/bnep-cloud-starter-plugin.jar"

echo ""
echo "Done! Plugin jar: $PLUGIN_JAR"
echo "Dist: $PROJECT_DIR/dist/bnep-cloud-starter-plugin.jar"
echo "To install: IDEA → Settings → Plugins → ⚙ → Install Plugin from Disk"
