import { NuiteeService } from '../src/modules/nuitee/nuitee.service';

function makeService() {
  const config = {
    get: (key: string) =>
      key === 'NUITEE_API_KEY' ? 'sand_test_key' : undefined,
  };
  return new NuiteeService(config as any);
}

function rows(count: number, start = 0) {
  return Array.from({ length: count }, (_, index) => ({
    id: `H${start + index}`,
    name: `Hotel ${start + index}`,
  }));
}

describe('NuiteeService.hotelContent — complete pagination', () => {
  afterEach(() => {
    delete process.env.NUITEE_HOTEL_PAGE_SIZE;
    delete process.env.NUITEE_HOTEL_MAX_PER_CITY;
    jest.restoreAllMocks();
  });

  it('walks every page instead of truncating at the first slice', async () => {
    const service = makeService();
    const request = jest.fn(async (path: string) => {
      const offset = Number(new URL(`https://x${path}`).searchParams.get('offset'));
      if (offset === 0) return { data: rows(200, 0), total: 250 };
      return { data: rows(50, 200), total: 250 };
    });
    (service as any).client.request = request;

    const result = await service.hotelContent('Cairo', 'EG');

    expect(result.success).toBe(true);
    expect(result.data).toHaveLength(250);
    expect(result.metadata).toMatchObject({
      complete: true,
      pagesFetched: 2,
      failedPages: [],
      totalReported: 250,
      fetched: 250,
    });
    expect(request).toHaveBeenCalledTimes(2);
    expect(request.mock.calls[0][0]).toContain('offset=0');
    expect(request.mock.calls[1][0]).toContain('offset=200');
  });

  it('stops as soon as the provider-reported total is reached', async () => {
    const service = makeService();
    const request = jest.fn(async () => ({ data: rows(200, 0), total: 200 }));
    (service as any).client.request = request;

    const result = await service.hotelContent('Cairo', 'EG');

    expect(request).toHaveBeenCalledTimes(1);
    expect(result.data).toHaveLength(200);
    expect(result.metadata).toMatchObject({ complete: true, pagesFetched: 1 });
  });

  it('is incomplete when the per-city cap, not the data, ended the walk', async () => {
    process.env.NUITEE_HOTEL_PAGE_SIZE = '100';
    process.env.NUITEE_HOTEL_MAX_PER_CITY = '200';
    const service = makeService();
    const request = jest.fn(async (path: string) => {
      const offset = Number(new URL(`https://x${path}`).searchParams.get('offset'));
      // No `total`: the provider is not telling us how much inventory exists.
      return { data: rows(100, offset) };
    });
    (service as any).client.request = request;

    const result = await service.hotelContent('Cairo', 'EG');

    expect(result.success).toBe(true);
    expect(result.data).toHaveLength(200);
    expect(result.metadata).toMatchObject({
      complete: false,
      truncatedAtCap: true,
      pagesFetched: 2,
      totalReported: null,
    });
  });

  it('is complete when no total is reported but the last page is short', async () => {
    process.env.NUITEE_HOTEL_PAGE_SIZE = '100';
    const service = makeService();
    const request = jest.fn(async (path: string) => {
      const offset = Number(new URL(`https://x${path}`).searchParams.get('offset'));
      return { data: offset === 0 ? rows(100, 0) : rows(20, 100) };
    });
    (service as any).client.request = request;

    const result = await service.hotelContent('Cairo', 'EG');

    expect(result.metadata).toMatchObject({
      complete: true,
      truncatedAtCap: false,
      pagesFetched: 2,
      totalReported: null,
    });
  });

  it('reports an incomplete sync when a later page fails after retries', async () => {
    const service = makeService();
    let call = 0;
    const request = jest.fn(async () => {
      call += 1;
      if (call === 1) return { data: rows(200, 0), total: 250 };
      throw new Error('provider 502');
    });
    (service as any).client.request = request;

    const result = await service.hotelContent('Cairo', 'EG');

    expect(result.success).toBe(true);
    expect(result.data).toHaveLength(200);
    expect(result.metadata).toMatchObject({
      complete: false,
      pagesFetched: 1,
      failedPages: [200],
    });
    // 1 successful page + 3 bounded attempts on the failed page.
    expect(request).toHaveBeenCalledTimes(4);
  }, 10_000);

  it('fails honestly when the first page never arrives', async () => {
    const service = makeService();
    (service as any).client.request = jest.fn(async () => {
      throw new Error('offline');
    });

    const result = await service.hotelContent('Cairo', 'EG');

    expect(result.success).toBe(false);
    expect(result.data).toBeUndefined();
    expect(result.metadata).toMatchObject({ complete: false });
  }, 10_000);

  it('reports the provider as disabled without a key', async () => {
    const config = { get: () => undefined };
    const service = new NuiteeService(config as any);
    const result = await service.hotelContent('Cairo', 'EG');
    expect(result.success).toBe(false);
    expect(result.error).toContain('NUITEE_API_KEY');
  });
});
