#!/bin/bash

# Quick sanity check to explain when the "Pool was force destroyed" race can/can't happen
# This does NOT change config. It just reads your current settings and tells you
# whether the pool-timeout race is even possible with the current timing.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_SHARD_ROOT="$(cd "${SCRIPT_DIR}/../../rumble-data-shard-wrk" && pwd)"

NET_CONF="${DATA_SHARD_ROOT}/config/facs/net.config.json"
COMMON_CONF="${DATA_SHARD_ROOT}/config/common.json"

if [[ ! -f "${NET_CONF}" || ! -f "${COMMON_CONF}" ]]; then
  echo "❌ Missing config files. Expected:"
  echo "   ${NET_CONF}"
  echo "   ${COMMON_CONF}"
  exit 1
fi

NET_CONF="${NET_CONF}" COMMON_CONF="${COMMON_CONF}" node <<'NODE'
const fs = require('fs')

const netConfPath = process.env.NET_CONF
const commonConfPath = process.env.COMMON_CONF

const net = JSON.parse(fs.readFileSync(netConfPath, 'utf8'))
const common = JSON.parse(fs.readFileSync(commonConfPath, 'utf8'))

const poolLingerMs = net?.r0?.poolLinger ?? net?.poolLinger ?? 300000
const poolLingerSec = poolLingerMs / 1000

const cronExpr = common?.wrk?.syncWalletTransfers
let intervalSec = null

// Only handle simple "*/N * * * * *" cron syntax
const cronMatch = typeof cronExpr === 'string'
  ? cronExpr.trim().match(/^\*\/(\d+)\s+/)
  : null

if (cronMatch) intervalSec = Number(cronMatch[1])

console.log('=== Pool Timeout Race Alignment Check ===')
console.log(`poolLinger: ${poolLingerMs}ms (${poolLingerSec}s) [config/facs/net.config.json r0]`)
console.log(`syncWalletTransfers: ${cronExpr ?? 'undefined'} [config/common.json]`)
console.log(`derived sync interval: ${intervalSec ? `${intervalSec}s` : 'unparsed'}`)
console.log('')

const messages = []
if (!intervalSec) {
  messages.push('⚠️  Cannot parse sync interval cron. Repro analysis skipped.')
} else if (intervalSec < poolLingerSec) {
  messages.push('ℹ️  Sync interval is shorter than poolLinger => pool never times out, no race.')
} else if (intervalSec >= poolLingerSec * 2) {
  messages.push('ℹ️  Sync interval is much longer than poolLinger => pool is destroyed well before the next job and is cleanly recreated (race not hit).')
} else {
  messages.push('✅ Timings are close enough to hit the race (next sync fires while linger timer is expiring).')
}

messages.forEach(m => console.log(m))

if (intervalSec) {
  console.log('')
  console.log('Tip: To force the race, keep the wallet ENABLED and make sync interval ≈ poolLinger.')
  console.log('     If interval << poolLinger, pool never dies. If interval >> poolLinger, it dies too early and is cleanly rebuilt.')
}
NODE
