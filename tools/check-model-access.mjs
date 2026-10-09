// Read-only capability probe. Never prints credentials or provider error bodies.
const key = process.env.OPENAI_API_KEY;
if (!key) {
  console.log(JSON.stringify({ available: false, reason: 'missing_api_key' }));
} else {
  try {
    const response = await fetch('https://api.openai.com/v1/models', {
      headers: { Authorization: `Bearer ${key}` }, signal: AbortSignal.timeout(15000)
    });
    if (!response.ok) console.log(JSON.stringify({ available: false, httpStatus: response.status }));
    else {
      const value = await response.json();
      console.log(JSON.stringify({ available: true,
        configuredModel: process.env.OPENAI_MODEL ?? null,
        candidates: (value.data ?? []).map(item => item.id).filter(id => /^gpt-(?:5\.4-mini|6\.1-sol|6-astra|6-luna)(?:-|$)/.test(id)) }));
    }
  } catch { console.log(JSON.stringify({ available: false, reason: 'connection_failed' })); }
}
