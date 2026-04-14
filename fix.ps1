$ErrorActionPreference = "Stop"
$root = "C:\Users\lexsc\Desktop\AstraAutoEx"
Set-Location $root

Write-Host "=== AstraAutoEx - 修复 4 个问题 ===" -ForegroundColor Cyan

# ── 修复1: Episode schema 添加 title/status ──
Write-Host "[1/4] 修复 Episode schema..." -ForegroundColor Yellow
$episodePath = "lib\astra_auto_ex\production\episode.ex"
$ep = Get-Content $episodePath -Raw -Encoding UTF8
$ep = $ep -replace '(field :episode_number, :integer)', "`$1`n    field :title, :string`n    field :name, :string`n    field :status, :string, default: ""draft"""
$ep = $ep -replace 'field :name, :string\r?\n\s+field :name, :string', 'field :name, :string'
$ep = $ep -replace '(:episode_number,)', "`$1`n      :title,`n      :name,`n      :status,"
Set-Content $episodePath $ep -Encoding UTF8 -NoNewline
Write-Host "  OK" -ForegroundColor Green

# ── 修复2: UserPreference 添加 user_id 到 cast ──
Write-Host "[2/4] 修复 UserPreference changeset..." -ForegroundColor Yellow
$prefPath = "lib\astra_auto_ex\accounts\user_preference.ex"
$pref = Get-Content $prefPath -Raw -Encoding UTF8
$pref = $pref -replace '\|> cast\(attrs, \[', "|> cast(attrs, [`n      :user_id,"
Set-Content $prefPath $pref -Encoding UTF8 -NoNewline
Write-Host "  OK" -ForegroundColor Green

# ── 修复3: 厂商2列布局 + MiniMax模型 ──
Write-Host "[3/4] 修复厂商布局 + MiniMax..." -ForegroundColor Yellow
$profilePath = "lib\astra_auto_ex_web\live\profile_live\index.ex"
$prof = Get-Content $profilePath -Raw -Encoding UTF8
$prof = $prof -replace 'class="grid gap-3"', 'class="grid grid-cols-1 md:grid-cols-2 gap-3"'
$prof = $prof -replace '"video" => \[%\{id: "minimax-hailuo-2\.3", name: "Hailuo 2\.3"\}\]', '"video" => [
          %{id: "minimax-hailuo-2.3", name: "Hailuo 2.3"},
          %{id: "minimax-hailuo-2.3-fast", name: "Hailuo 2.3 Fast"}
        ]'
$prof = $prof -replace 'music-2\.5', 'music-2.6'
$prof = $prof -replace 'Music 2\.5', 'Music 2.6'
Set-Content $profilePath $prof -Encoding UTF8 -NoNewline
Write-Host "  OK" -ForegroundColor Green

# ── 修复4: 数据库迁移 ──
Write-Host "[4/4] 创建迁移文件..." -ForegroundColor Yellow
$migContent = @'
defmodule AstraAutoEx.Repo.Migrations.AddTitleStatusToEpisodes do
  use Ecto.Migration

  def change do
    alter table(:episodes) do
      add :title, :string
      add :status, :string, default: "draft"
    end
  end
end
'@
Set-Content "priv\repo\migrations\20260414000001_add_title_status_to_episodes.exs" $migContent -Encoding UTF8
Write-Host "  OK" -ForegroundColor Green

# ── 提交推送 ──
Write-Host "`n[推送中...]" -ForegroundColor Yellow
git add -A
git commit -m "fix: resolve 4 project issues"
git push -u origin main --force

Write-Host "`n=== 全部完成！ ===" -ForegroundColor Green
pause
