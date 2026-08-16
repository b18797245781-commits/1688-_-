$ErrorActionPreference = 'Stop'
$content = Get-Content -Path 'e:\trea\trae 本地\1688店铺榜_还原\1688店铺榜_优质供应商榜单_店雷达.html' -Raw -Encoding UTF8

$marker = '<div data-v-15523a56="" data-v-7d2268d5="" class="rank-card">'
$parts = $content -split [regex]::Escape($marker)
$cards = $parts | Select-Object -Skip 1

$results = @()
$cardIdx = 0
foreach ($card in $cards) {
    $cardIdx++
    if ($cardIdx -gt 20) { break }

    # 1. Rank number
    $rankMatch = [regex]::Match($card, 'rank-no--(\d+)')
    $rank = if ($rankMatch.Success) { $rankMatch.Groups[1].Value } else { '' }

    # 2. Company name & 3. Shop URL
    $companyMatch = [regex]::Match($card, 'href="([^"]*)"[^>]*class="company[^"]*">([^<]+)</a>')
    $shopUrl = if ($companyMatch.Success) { $companyMatch.Groups[1].Value } else { '' }
    $companyName = if ($companyMatch.Success) { $companyMatch.Groups[2].Value.Trim() } else { '' }

    # 4. Trade medal stars - use aria-label
    $medalLabelMatch = [regex]::Match($card, 'aria-label="[^"]*?(\d+)[^"]*?"[^>]*class="trade-medal__items"')
    $medalStars = ''
    if ($medalLabelMatch.Success) { $medalStars = $medalLabelMatch.Groups[1].Value }
    if (-not $medalStars) {
        $itemsMatch = [regex]::Match($card, 'trade-medal__items">(.*?)</span>')
        if ($itemsMatch.Success) {
            $medalStars = ([regex]::Matches($itemsMatch.Groups[1].Value, 'medal\.png')).Count
        }
    }

    # 5. Qualification tags (power tag)
    $qualTags = @()
    $qualPowerMatches = [regex]::Matches($card, 'qualification-tag qualification-tag--power">.*?<span[^>]*>([^<]+)</span>')
    foreach ($m in $qualPowerMatches) { $qualTags += $m.Groups[1].Value.Trim() }
    $qualStr = $qualTags -join ','

    # 6. Years
    $yearMatch = [regex]::Match($card, 'qualification-tag--year">.*?<span[^>]*>([^<]+)</span>')
    $years = if ($yearMatch.Success) { $yearMatch.Groups[1].Value.Trim() } else { '' }

    # 7. Shop type tag
    $shopTypeMatch = [regex]::Match($card, 'tag tag--shop">([^<]+)</span>')
    $storeTypeMatch = [regex]::Match($card, 'tag tag--store">([^<]+)</span>')
    $shopType = if ($shopTypeMatch.Success) { $shopTypeMatch.Groups[1].Value.Trim() }
    elseif ($storeTypeMatch.Success) { $storeTypeMatch.Groups[1].Value.Trim() } else { '' }

    # 8-12. Metrics - extract all metric strong+span pairs
    $metricMatches = [regex]::Matches($card, '<strong([^>]*)>([^<]*)</strong>\s*<span[^>]*>([^<]+)</span>')

    $score = ''; $orders30 = ''; $pickupRate = ''; $response3min = 'N/A'; $weeklyTrend = ''
    $remaining = New-Object System.Collections.ArrayList
    foreach ($m in $metricMatches) {
        $attrs = $m.Groups[1].Value
        $val = $m.Groups[2].Value.Trim()
        $label = $m.Groups[3].Value.Trim()
        if ($attrs -match 'class="score"') {
            $score = $val
        } else {
            [void]$remaining.Add(@{Val=$val; Label=$label})
        }
    }

    # remaining metrics in order: [0]=30day orders, then 48h pickup (contains 48h), then optional 3min, then weekly trend (last)
    if ($remaining.Count -ge 1) { $orders30 = $remaining[0].Val }
    for ($i = 1; $i -lt $remaining.Count; $i++) {
        if ($remaining[$i].Label -match '48h') { $pickupRate = $remaining[$i].Val }
    }
    if ($remaining.Count -ge 2) {
        # last one is weekly trend
        $weeklyTrend = $remaining[$remaining.Count - 1].Val
        # any metric between index 0 and last that is not 48h = 3min response
        for ($i = 1; $i -lt ($remaining.Count - 1); $i++) {
            if ($remaining[$i].Label -notmatch '48h') {
                $response3min = $remaining[$i].Val
            }
        }
        # If pickup not found yet via 48h, assign by position
        if (-not $pickupRate) {
            if ($remaining.Count -ge 2) { $pickupRate = $remaining[1].Val }
        }
    }

    # 13. Offers
    $offerUrlMatches = [regex]::Matches($card, 'href="([^"]*)"[^>]*class="offer"')
    $offerTextMatches = [regex]::Matches($card, 'class="offer"[^>]*>.*?<span[^>]*>([^<]*)</span>')
    $offerCount = [Math]::Min($offerUrlMatches.Count, $offerTextMatches.Count)
    $offerLinks = @()
    for ($i = 0; $i -lt $offerCount; $i++) {
        $offerLinks += ($offerUrlMatches[$i].Groups[1].Value + ' (' + $offerTextMatches[$i].Groups[1].Value.Trim() + ')')
    }
    $offersStr = $offerLinks -join '; '

    # 14. Action buttons
    $btnMatches = [regex]::Matches($card, 'rank-action-button[^>]*>([^<]*)</button>')
    $btns = @()
    foreach ($m in $btnMatches) { $btns += $m.Groups[1].Value.Trim() }
    $btnsStr = $btns -join ','

    $results += "$rank|$companyName|$shopUrl|$medalStars|$qualStr|$years|$shopType|$score|$orders30|$pickupRate|$response3min|$weeklyTrend|$offersStr|$btnsStr"
}

Write-Output "TOTAL_CARDS: $cardIdx"
$results | ForEach-Object { Write-Output $_ }
