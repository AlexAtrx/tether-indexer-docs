/*
 * Read-only daily onboarding report.
 *
 * Counts:
 * - shardAssignedUsers: users with a user->data-shard ORK lookup created that day.
 * - usersWithWalletCreated: distinct users with a type=user wallet created that day.
 * - walletsCreated: raw type=user wallet rows created that day.
 *
 * Usage, single data-shard DB:
 *
 *   ORK_URI='mongodb://user:pass@host1,host2,host3/wdk_ork?replicaSet=rs0&authSource=admin' \
 *   DATA_SHARD_URI='mongodb://user:pass@host1,host2,host3/wdk_data_shard?replicaSet=rs0&authSource=admin' \
 *   DAYS=28 \
 *   mongosh --quiet onboarding-daily-report.mongosh.js > onboarding-daily.csv
 *
 * Usage, multiple data-shard DBs in one cluster:
 *
 *   ORK_URI='mongodb://user:pass@host1,host2,host3/wdk_ork?replicaSet=rs0&authSource=admin' \
 *   DATA_SHARD_URI='mongodb://user:pass@host1,host2,host3/admin?replicaSet=rs0&authSource=admin' \
 *   DATA_SHARD_DBS='wdk_data_shard_1,wdk_data_shard_2,wdk_data_shard_3' \
 *   DAYS=28 \
 *   mongosh --quiet onboarding-daily-report.mongosh.js > onboarding-daily.csv
 *
 * Usage, multiple data-shard URIs:
 *
 *   ORK_URI='mongodb://.../wdk_ork?...' \
 *   DATA_SHARD_URIS='mongodb://.../wdk_data_shard_1?...|mongodb://.../wdk_data_shard_2?...' \
 *   DAYS=28 \
 *   mongosh --quiet onboarding-daily-report.mongosh.js > onboarding-daily.csv
 *
 * Optional:
 *   SINCE=2026-04-15       inclusive UTC date
 *   UNTIL=2026-05-13       exclusive UTC date
 *   REPORT_TZ=UTC          Mongo timezone used for daily buckets
 *   ORK_DB=wdk_ork         required only if ORK_URI has no DB path
 *   DATA_SHARD_DB=...      required only if DATA_SHARD_URI has no DB path
 */

const DAY_MS = 24 * 60 * 60 * 1000

function env (name, fallback = undefined) {
  return process.env[name] || fallback
}

function requiredEnv (name) {
  const value = env(name)
  if (!value) {
    throw new Error(`Missing required env var ${name}`)
  }
  return value
}

function parseUtcDay (value, name) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw new Error(`${name} must be YYYY-MM-DD`)
  }
  return new Date(`${value}T00:00:00.000Z`)
}

function defaultUntilUtc () {
  const now = new Date()
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1))
}

function dbNameFromUri (uri, fallback, label) {
  if (fallback) return fallback

  const withoutQuery = uri.split('?')[0]
  const withoutProtocolAndHosts = withoutQuery.replace(/^mongodb(?:\+srv)?:\/\/[^/]+\/?/, '')
  const dbName = withoutProtocolAndHosts.split('/').filter(Boolean).pop()

  if (!dbName) {
    throw new Error(`${label} DB name missing. Put it in the URI path or set ${label}_DB.`)
  }

  return decodeURIComponent(dbName)
}

function splitDbNames (value) {
  return value.split(',').map(s => s.trim()).filter(Boolean)
}

function getDataShardTargets () {
  const shardUris = env('DATA_SHARD_URIS')
  if (shardUris) {
    return shardUris.split('|').map(s => s.trim()).filter(Boolean).map(uri => ({
      uri,
      dbName: dbNameFromUri(uri, null, 'DATA_SHARD')
    }))
  }

  const uri = requiredEnv('DATA_SHARD_URI')
  const dbNames = env('DATA_SHARD_DBS')
  if (dbNames) {
    return splitDbNames(dbNames).map(dbName => ({ uri, dbName }))
  }

  return [{
    uri,
    dbName: dbNameFromUri(uri, env('DATA_SHARD_DB'), 'DATA_SHARD')
  }]
}

function dayKeyFromDate (date) {
  return date.toISOString().slice(0, 10)
}

function makeDayRows (from, until) {
  const rows = []
  for (let ts = from.getTime(); ts < until.getTime(); ts += DAY_MS) {
    rows.push({
      date: dayKeyFromDate(new Date(ts)),
      shardAssignedUsers: 0,
      usersWithWalletCreated: 0,
      walletsCreated: 0
    })
  }
  return rows
}

function mergeByDay (rows, day, patch) {
  const row = rows.find(r => r.date === day)
  if (!row) return
  for (const [key, value] of Object.entries(patch)) {
    row[key] += value || 0
  }
}

function printCsv (rows) {
  print('date,shardAssignedUsers,usersWithWalletCreated,walletsCreated,diffAssignedMinusUsersWithWallet')
  for (const row of rows) {
    const diff = row.shardAssignedUsers - row.usersWithWalletCreated
    print([
      row.date,
      row.shardAssignedUsers,
      row.usersWithWalletCreated,
      row.walletsCreated,
      diff
    ].join(','))
  }
}

const timezone = env('REPORT_TZ', 'UTC')
const until = env('UNTIL') ? parseUtcDay(env('UNTIL'), 'UNTIL') : defaultUntilUtc()
const from = env('SINCE')
  ? parseUtcDay(env('SINCE'), 'SINCE')
  : new Date(until.getTime() - Number(env('DAYS', '28')) * DAY_MS)

if (!(from < until)) {
  throw new Error('SINCE/from must be before UNTIL')
}

const rows = makeDayRows(from, until)
const orkUri = requiredEnv('ORK_URI')
const orkDbName = dbNameFromUri(orkUri, env('ORK_DB'), 'ORK')
const fromObjectId = ObjectId.createFromTime(Math.floor(from.getTime() / 1000))
const untilObjectId = ObjectId.createFromTime(Math.floor(until.getTime() / 1000))

console.error(`Report range: ${from.toISOString()} <= ts < ${until.toISOString()}`)
console.error(`Bucket timezone: ${timezone}`)

const ork = new Mongo(orkUri).getDB(orkDbName)
const orkLookups = ork.getCollection('wdk_ork_lookups')

const idTypes = orkLookups.aggregate([
  { $match: { type: 'users' } },
  { $group: { _id: { $type: '$_id' }, count: { $sum: 1 } } },
  { $sort: { count: -1 } }
]).toArray()

console.error(`ORK DB: ${orkDbName}`)
console.error(`ORK user lookup _id types: ${JSON.stringify(idTypes)}`)

const assignedRows = orkLookups.aggregate([
  {
    $match: {
      type: 'users',
      _id: {
        $type: 'objectId',
        $gte: fromObjectId,
        $lt: untilObjectId
      }
    }
  },
  {
    $group: {
      _id: {
        $dateToString: {
          format: '%Y-%m-%d',
          date: { $toDate: '$_id' },
          timezone
        }
      },
      shardAssignedUsers: { $sum: 1 }
    }
  },
  { $sort: { _id: 1 } }
]).toArray()

for (const row of assignedRows) {
  mergeByDay(rows, row._id, { shardAssignedUsers: row.shardAssignedUsers })
}

for (const target of getDataShardTargets()) {
  const dataShardDb = new Mongo(target.uri).getDB(target.dbName)
  const wallets = dataShardDb.getCollection('wdk_data_shard_wallets')

  console.error(`Data shard DB: ${target.dbName}`)

  const walletRows = wallets.aggregate([
    {
      $match: {
        type: 'user',
        createdAt: {
          $gte: from.getTime(),
          $lt: until.getTime()
        }
      }
    },
    {
      $group: {
        _id: {
          day: {
            $dateToString: {
              format: '%Y-%m-%d',
              date: { $toDate: '$createdAt' },
              timezone
            }
          },
          userId: '$userId'
        },
        wallets: { $sum: 1 }
      }
    },
    {
      $group: {
        _id: '$_id.day',
        usersWithWalletCreated: { $sum: 1 },
        walletsCreated: { $sum: '$wallets' }
      }
    },
    { $sort: { _id: 1 } }
  ]).toArray()

  for (const row of walletRows) {
    mergeByDay(rows, row._id, {
      usersWithWalletCreated: row.usersWithWalletCreated,
      walletsCreated: row.walletsCreated
    })
  }
}

printCsv(rows)
