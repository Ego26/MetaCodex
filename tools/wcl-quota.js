// Was Warcraft Logs uns gerade zugesteht.
//
//     node tools/wcl-quota.js .
//
// WARUM ES DIESE DATEI GIBT. Die Nacht auf den 26.09. sammelte fuenfeinhalb
// Stunden, und fast alles davon war Warten am Stundenlimit. Die Frage
// "wir haben doch Gold mit 9000 Punkten" laesst sich nicht aus der
// Laufzeit beantworten, sondern nur, indem man fragt - und die Antwort
// kostet einen einzigen Punkt.
//
// Sie sagt dreierlei: wie hoch das Limit wirklich ist (3600 = frei,
// 9000 = Gold), wieviel diese Stunde schon verbraucht ist, und wann sie
// zurueckgesetzt wird. Nichts davon verraet die Zugangsdaten.
const https = require('https');
const fs = require('fs');
const path = require('path');

const BASE = process.argv[2] || '.';

function credentials() {
  if (process.env.WCL_CLIENT_ID && process.env.WCL_CLIENT_SECRET) {
    return { id: process.env.WCL_CLIENT_ID, secret: process.env.WCL_CLIENT_SECRET };
  }
  const file = path.join(BASE, 'tools', 'wcl-credentials.json');
  if (!fs.existsSync(file)) {
    console.error('Keine Zugangsdaten: ' + file + ' fehlt, und WCL_CLIENT_ID ist nicht gesetzt.');
    process.exit(1);
  }
  const json = JSON.parse(fs.readFileSync(file, 'utf8'));
  return { id: json.clientId, secret: json.clientSecret };
}

function request(options, body) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let text = '';
      res.setEncoding('utf8');
      res.on('data', (c) => (text += c));
      res.on('end', () => {
        if (res.statusCode !== 200) {
          return reject(new Error('HTTP ' + res.statusCode + ': ' + text.slice(0, 200)));
        }
        try { resolve(JSON.parse(text)); } catch (err) { reject(err); }
      });
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

(async () => {
  const { id, secret } = credentials();
  const auth = Buffer.from(id + ':' + secret).toString('base64');
  const token = (await request({
    method: 'POST',
    hostname: 'www.warcraftlogs.com',
    path: '/oauth/token',
    headers: {
      'Authorization': 'Basic ' + auth,
      'Content-Type': 'application/x-www-form-urlencoded',
      'Content-Length': 29,
    },
  }, 'grant_type=client_credentials')).access_token;

  const body = JSON.stringify({
    query: '{ rateLimitData { limitPerHour pointsSpentThisHour pointsResetIn } }',
  });
  const json = await request({
    method: 'POST',
    hostname: 'www.warcraftlogs.com',
    path: '/api/v2/client',
    headers: {
      'Authorization': 'Bearer ' + token,
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(body),
    },
  }, body);

  const d = json.data.rateLimitData;
  const left = d.limitPerHour - d.pointsSpentThisHour;
  console.log('Limit je Stunde:   ' + d.limitPerHour
    + (d.limitPerHour >= 9000 ? '  (Gold)' : '  (kein Gold!)'));
  console.log('Diese Stunde weg:  ' + Math.round(d.pointsSpentThisHour));
  console.log('Noch uebrig:       ' + Math.round(left));
  console.log('Ruecksetzung in:   ' + Math.round(d.pointsResetIn / 60) + ' Minuten');
})().catch((err) => {
  console.error(String(err.message || err));
  process.exit(1);
});
