// Selema Gold — email relay. Deploy as Web app: Execute as "Me", Who has access "Anyone".
const KEY = 'selema-gold-2026';

function doPost(e) {
  try {
    const d = JSON.parse(e.postData.contents);
    if (d.key !== KEY) return out_({ ok: false, error: 'bad key' });
    MailApp.sendEmail({
      to: d.to,
      subject: d.subject || 'Selema Gold',
      htmlBody: d.html || '',
      name: 'Selema Trading',
    });
    return out_({ ok: true });
  } catch (err) {
    return out_({ ok: false, error: String(err) });
  }
}

function out_(o) {
  return ContentService.createTextOutput(JSON.stringify(o)).setMimeType(ContentService.MimeType.JSON);
}

// Run once from the editor to grant Gmail permission.
function authorize() {
  MailApp.getRemainingDailyQuota();
}
