# 加载配置并运行
$configContent = Get-Content -Raw -Path "config.json"
$config = $configContent | ConvertFrom-Json
$env:CONFIG = $configContent
if ($config.AES_KEY) {
    $env:AES_KEY = $config.AES_KEY
}
python main.py