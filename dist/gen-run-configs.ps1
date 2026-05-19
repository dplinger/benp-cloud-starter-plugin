# 在目标项目中生成 BNEP Cloud Run Configuration XML 文件
param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath
)

$ConfigDir = "$ProjectPath\.idea\runConfigurations"

if (-not (Test-Path $ProjectPath)) {
    Write-Host "[ERROR] Project path not found: $ProjectPath" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path "$ProjectPath\pom.xml")) {
    Write-Host "[WARN] No pom.xml in project path, is this a Maven project?" -ForegroundColor Yellow
}

New-Item -ItemType Directory -Force $ConfigDir | Out-Null

$modules = @(
    @{Name="GatewayServerApplication";         Main="com.bnep.GatewayServerApplication";               Module="bnep-gateway-server"},
    @{Name="BaseServerApplication";            Main="com.bnep.base.server.BaseServerApplication";        Module="bnep-base-server"},
    @{Name="AiInfrastructureServerApplication"; Main="com.bnep.aiInfrastructure.AiInfrastructureServerApplication"; Module="bnep-aiInfrastructure-server"},
    @{Name="WaterServerApplication";           Main="com.bnep.water.server.WaterServerApplication";      Module="bnep-water-server"},
    @{Name="CheckServerApplication";           Main="com.bnep.check.server.CheckServerApplication";      Module="bnep-check-server"},
    @{Name="BigScreenServerApplication";       Main="com.bnep.bigscreen.server.BigScreenServerApplication"; Module="bnep-bigscreen-server"},
    @{Name="MonitorServerApplication";         Main="com.bnep.monitor.MonitorServerApplication";         Module="bnep-monitor"},
    @{Name="SourceServerApplication";          Main="com.bnep.source.server.SourceServerApplication";    Module="bnep-source-server"},
    @{Name="CarbonServerApplication";          Main="com.bnep.carbon.server.CarbonServerApplication";    Module="bnep-carbon-server"},
    @{Name="DataTransferServerApplication";    Main="com.bnep.datatransfer.server.DataTransferServerApplication"; Module="bnep-datatransfer-server"},
    @{Name="ControlServerApplication";         Main="com.bnep.control.server.ControlServerApplication";  Module="bnep-control-server"},
    @{Name="CommunalAuxServerApplication";     Main="com.bnep.communalAux.server.CommunalAuxServerApplication"; Module="bnep-communalAux-server"},
    @{Name="CommunalServerApplication";        Main="com.bnep.communal.server.CommunalServerApplication"; Module="bnep-communal-server"},
    @{Name="EventServerApplication";           Main="com.bnep.event.server.EventServerApplication";      Module="bnep-event-server"},
    @{Name="IotServerApplication";             Main="com.bnep.iot.server.IotServerApplication";          Module="bnep-iot-server"},
    @{Name="AtmosphereServerApplication";      Main="com.bnep.atmosphere.server.AtmosphereServerApplication"; Module="bnep-atmosphere-server"},
    @{Name="OperatorServerApplication";        Main="com.bnep.operator.server.OperatorServerApplication"; Module="bnep-operator-server"},
    @{Name="DossierServerApplication";         Main="com.bnep.dossier.server.DossierServerApplication";   Module="bnep-dossier-server"},
    @{Name="FlowableServerApplication";        Main="com.bnep.flowable.server.FlowableServerApplication"; Module="bnep-flowable-server"},
    @{Name="NoticeServerApplication";          Main="com.bnep.notice.server.NoticeServerApplication";    Module="bnep-notice-server"},
    @{Name="OffsiteServerApplication";         Main="com.bnep.offsite.server.OffsiteServerApplication";  Module="bnep-offsite-server"},
    @{Name="AnalysisServerApplication";        Main="com.bnep.analysis.server.AnalysisServerApplication"; Module="bnep-analysis-server"}
)

$count = 0
foreach ($m in $modules) {
    $xml = @"
<component name="ProjectRunConfigurationManager">
  <configuration default="false" name="$($m.Name)" type="Application" factoryName="Application" nameIsGenerated="true">
    <option name="MAIN_CLASS_NAME" value="$($m.Main)" />
    <module name="$($m.Module)" />
    <method v="2">
      <option name="Make" enabled="true" />
    </method>
  </configuration>
</component>
"@
    $xml | Out-File -FilePath "$ConfigDir\$($m.Name).xml" -Encoding utf8 -NoNewline
    $count++
}

Write-Host "[OK] Generated $count run configurations in $ConfigDir" -ForegroundColor Green
