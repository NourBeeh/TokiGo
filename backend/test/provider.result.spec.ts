describe('ProviderResult', () => {
  it('should create success result', () => {
    const result = {
      success: true,
      providerId: 'p1',
      providerName: 'Test',
      data: [],
      timestamp: new Date(),
    };
    expect(result.success).toBe(true);
  });
});
