const request = require('supertest');
const app = require('./server');

describe('health endpoints', () => {
  it('GET /health returns 200 and ok status', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ok');
  });

  it('GET /ready returns 200 when reachable or 503 when not', async () => {
    const res = await request(app).get('/ready');
    expect([200, 503]).toContain(res.statusCode);
  });
});
