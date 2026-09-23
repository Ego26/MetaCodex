// Battle.net API: token and GET, with the same rules as the other sources.
//
// Credentials: tools/bnet-credentials.json ({ clientId, clientSecret }) or
// the environment variables BNET_CLIENT_ID and BNET_CLIENT_SECRET. The
// file is gitignored; the Action reads the repository secrets.
//
// Why Blizzard next to raider.io: the character profile carries the
// loadouts of EVERY specialisation, not only the active one. A raider
// between raid nights has their M+ build active - Blizzard still shows the
// raid spec's loadout, so verification against the logged fight passes
// far more often.

const fs = require('fs');
const path = require('path');
const https = require('https');

let token = null;
let tokenUntil = 0;

function credentials(base) {
  if (process.env.BNET_CLIENT_ID && process.env.BNET_CLIENT_SECRET) {
    return { id: process.env.BNET_CLIENT_ID, secret: process.env.BNET_CLIENT_SECRET };
  }
  const file = path.join(base, 'tools', 'bnet-credentials.json');
  if (!fs.existsSync(file)) return null;
  const j = JSON.parse(fs.readFileSync(file, 'utf8'));
  if (!j.clientId || !j.clientSecret || /your /.test(j.clientId)) return null;
  return { id: j.clientId, secret: j.clientSecret };
}

/** Whether Battle.net can be used at all. */
function available(base) {
  return credentials(base) !== null;
}

function request(options, body) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (c) => (data += c));
      res.on('end', () => resolve({ status: res.statusCode, body: data }));
    });
    req.on('error', reject);
    req.setTimeout(30000, () => { req.destroy(); reject(new Error('timeout')); });
    if (body) req.write(body);
    req.end();
  });
}

async function getToken(base) {
  if (token && Date.now() < tokenUntil) return token;
  const cred = credentials(base);
  if (!cred) throw new Error('no Battle.net credentials');
  const res = await request({
    hostname: 'oauth.battle.net', path: '/token', method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      Authorization: 'Basic ' + Buffer.from(cred.id + ':' + cred.secret).toString('base64'),
    },
  }, 'grant_type=client_credentials');
  const j = JSON.parse(res.body);
  if (!j.access_token) throw new Error('Battle.net token: ' + res.body.slice(0, 120));
  token = j.access_token;
  tokenUntil = Date.now() + ((j.expires_in || 3600) - 60) * 1000;
  return token;
}

/**
 * GET a Game Data or Profile endpoint.
 * @param base repo root (for the credentials file)
 * @param region "eu" | "us" | "kr" | "tw"
 * @param apiPath e.g. "/profile/wow/character/kazzak/name/specializations"
 * @param namespace e.g. "profile-eu"
 * @returns parsed JSON, or null on 404
 */
async function get(base, region, apiPath, namespace, locale) {
  const tok = await getToken(base);
  const host = region === 'cn' ? 'gateway.battlenet.com.cn' : region + '.api.blizzard.com';
  const sep = apiPath.includes('?') ? '&' : '?';
  const full = apiPath + sep + 'namespace=' + encodeURIComponent(namespace) + '&locale=' + (locale || 'en_US');
  for (let attempt = 0; attempt < 3; attempt += 1) {
    const res = await request({ hostname: host, path: full, method: 'GET', headers: { Authorization: 'Bearer ' + tok } });
    if (res.status === 404) return null;
    if (res.status === 429) { await new Promise((r) => setTimeout(r, 2000)); continue; }
    if (res.status !== 200) throw new Error('Battle.net ' + res.status + ' ' + apiPath);
    return JSON.parse(res.body);
  }
  throw new Error('Battle.net 429 ' + apiPath);
}

module.exports = { available, get };
