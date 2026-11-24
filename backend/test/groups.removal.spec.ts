import { readdirSync, readFileSync, existsSync } from 'fs';
import { join } from 'path';

/**
 * Groups removal guard (R9).
 *
 * The backend never had a Groups module, but this test fails if one is ever
 * reintroduced: no module/controller/entity/migration/endpoint may be named
 * for Groups, and no route path may expose it.
 */
describe('Groups removal (backend)', () => {
  const src = join(__dirname, '..', 'src');

  function walk(dir: string): string[] {
    const out: string[] = [];
    if (!existsSync(dir)) return out;
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const full = join(dir, entry.name);
      if (entry.isDirectory()) out.push(...walk(full));
      else out.push(full);
    }
    return out;
  }

  const files = walk(src).filter((file) => /\.ts$/.test(file));

  it('has no Groups module, controller, entity or migration', () => {
    const offenders = files.filter((file) => /group/i.test(file));
    expect(offenders).toEqual([]);
  });

  it('has no Groups route path or controller decorator', () => {
    const offenders = files.filter((file) => {
      const text = readFileSync(file, 'utf8');
      return (
        /@Controller\(\s*['"`]groups/.test(text) ||
        /path:\s*['"`]groups['"`]/.test(text) ||
        /@Get\(\s*['"`]groups/.test(text)
      );
    });
    expect(offenders).toEqual([]);
  });

  it('leaves the unrelated flight "journey groups" concept untouched', () => {
    // The flight adapter's `groups` local is a provider response shape, not
    // the removed product feature. Guard against an over-eager cleanup.
    const flight = readFileSync(join(src, 'modules', 'nuitee', 'nuitee.flight.service.ts'), 'utf8');
    expect(flight).toContain('const groups = Array.isArray(response?.data)');
  });
});
