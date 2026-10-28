export interface ProviderResult<T> {
  success: boolean;
  providerId: string;
  providerName: string;
  data?: T;
  error?: string;
  timestamp: Date;
  metadata?: Record<string, any>;
}
