/**
 * Minimal ambient declarations for the `meilisearch` package.
 *
 * The SDK ships ESM-oriented type resolution that the project's classic
 * `moduleResolution: node` cannot follow; rather than change the whole
 * project's module strategy, we declare only the surface the backend uses.
 * At runtime the real SDK is loaded normally.
 */
declare module 'meilisearch' {
  export interface Config {
    host: string;
    apiKey?: string;
  }

  export interface EnqueuedTaskLike {
    taskUid?: number;
    [key: string]: any;
  }

  export interface SearchResponse<T> {
    hits: T[];
    estimatedTotalHits?: number;
    totalHits?: number;
    [key: string]: any;
  }

  export interface Index<T = any> {
    addDocuments(documents: T[], options?: any): Promise<EnqueuedTaskLike>;
    deleteDocument(documentId: string | number, options?: any): Promise<EnqueuedTaskLike>;
    updateSettings(settings: any): Promise<EnqueuedTaskLike>;
    search<D = T>(
      query?: string | null,
      options?: any,
    ): Promise<SearchResponse<D>>;
    [key: string]: any;
  }

  export interface TaskClient {
    waitForTask(taskUidOrTask: number | EnqueuedTaskLike, options?: any): Promise<any>;
    [key: string]: any;
  }

  export class Meilisearch {
    constructor(config: Config);
    config: Config;
    index<T = any>(indexUid: string): Index<T>;
    createIndex(indexUid: string, options?: any): Promise<EnqueuedTaskLike>;
    get tasks(): TaskClient;
    isHealthy(): Promise<boolean>;
    health(): Promise<any>;
    [key: string]: any;
  }
}
