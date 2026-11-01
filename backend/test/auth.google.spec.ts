import { validate } from 'class-validator';
import {
  ConflictException,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Repository } from 'typeorm';

import { GoogleLoginDto } from '../src/common/dto/auth.dto';
import { AuthService } from '../src/modules/auth/auth.service';
import { GoogleTokenVerifier } from '../src/modules/auth/google-token.verifier';
import { User } from '../src/database/entities/user.entity';

const VERIFIED_PROFILE = {
  subject: 'google-sub-1',
  email: 'traveler@example.com',
  emailVerified: true,
  displayName: 'Nour',
  pictureUrl: 'https://example.com/a.png',
};

const makeService = () => {
  const users = {
    findOne: jest.fn(),
    create: jest.fn((data: Partial<User>) => ({ ...data }) as User),
    save: jest.fn(
      async (data: Partial<User>): Promise<User> =>
        ({
          id: 'user-1',
          email: data.email ?? '',
          displayName: data.displayName ?? null,
          googleId: data.googleId ?? null,
          isActive: true,
          role: 'user',
          ...data,
        }) as User,
    ),
  };

  // `loginWithGoogle` looks the account up with a QueryBuilder so the
  // select:false password column is available, mirroring `login`.
  let whereSubject = '';
  let whereEmail = '';
  let result: unknown = null;
  (users as unknown as Record<string, unknown>).createQueryBuilder = jest.fn(() => {
    const qb = {
      addSelect: () => qb,
      where: (_sql: string, params: { subject: string }) => {
        whereSubject = params.subject;
        return qb;
      },
      orWhere: (_sql: string, params: { email: string }) => {
        whereEmail = params.email;
        return qb;
      },
      getOne: async () => {
        void whereSubject;
        void whereEmail;
        return result;
      },
    };
    return qb;
  });

  const jwtService = {
    signAsync: jest.fn(async (payload: object) => `signed:${JSON.stringify(payload)}`),
  };
  const config = {
    get: jest.fn((key: string) => {
      if (key === 'jwt.refreshSecret') return 'test-refresh-secret';
      if (key === 'jwt.accessExpiresIn') return '15m';
      if (key === 'jwt.refreshExpiresIn') return '7d';
      return undefined;
    }),
  };

  const verifier = { verify: jest.fn(async () => ({ ...VERIFIED_PROFILE })) };

  const service = new AuthService(
    jwtService as unknown as JwtService,
    config as unknown as ConfigService,
    users as unknown as Repository<User>,
    verifier as unknown as GoogleTokenVerifier,
  );

  return {
    service,
    users,
    verifier,
    // Set the account the lookup resolves to (null = no such account).
    existing: (value: unknown) => {
      result = value;
    },
  };
};

describe('GoogleLoginDto validation', () => {
  it('requires a credential and bounds its size', async () => {
    const empty = new GoogleLoginDto();
    empty.idToken = '';
    expect((await validate(empty)).some((e) => e.property === 'idToken')).toBe(true);

    const oversized = new GoogleLoginDto();
    oversized.idToken = 'a'.repeat(4097);
    expect(
      (await validate(oversized)).some((e) => e.property === 'idToken'),
    ).toBe(true);

    const valid = new GoogleLoginDto();
    valid.idToken = `header.${'a'.repeat(64)}.signature`;
    expect(await validate(valid)).toHaveLength(0);
  });

  it('drops unexpected fields (global pipe uses whitelist)', async () => {
    // A client sending its own profile must not get it trusted: only idToken is
    // even a valid property of the DTO.
    expect(Object.getOwnPropertyNames(new GoogleLoginDto())).not.toContain(
      'displayName',
    );
  });
});

describe('AuthService.loginWithGoogle', () => {
  it('creates an account on first Google sign-in and issues our own tokens', async () => {
    const { service, users, existing } = makeService();
    existing(null);
    users.save.mockImplementationOnce(async (data: Partial<User>) => ({
      ...data,
      id: 'google-user-1',
      role: 'user',
    }) as User);

    const result = await service.loginWithGoogle({ idToken: 'token' });

    const created = users.create.mock.calls[0][0];
    expect(created.email).toBe('traveler@example.com');
    expect(created.googleId).toBe('google-sub-1');
    expect(created.displayName).toBe('Nour');
    // No password is ever invented for a Google-only account.
    expect(created.passwordHash).toBeUndefined();
    expect(result.user.id).toBe('google-user-1');
    expect(result.accessToken).toContain('signed:');
    expect(result.refreshToken).toContain('signed:');
    expect(JSON.stringify(result)).not.toContain('passwordHash');
  });

  it('rejects an unverified Google email without touching the database', async () => {
    const { service, users, verifier } = makeService();
    verifier.verify.mockResolvedValueOnce({
      ...VERIFIED_PROFILE,
      emailVerified: false,
    });

    await expect(service.loginWithGoogle({ idToken: 'token' })).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
    expect(users.save).not.toHaveBeenCalled();
  });

  it('signs in an existing Google account', async () => {
    const { service, users, existing } = makeService();
    existing({
      id: 'user-9',
      email: 'traveler@example.com',
      displayName: 'Nour',
      googleId: 'google-sub-1',
      passwordHash: null,
      isActive: true,
    });

    const result = await service.loginWithGoogle({ idToken: 'token' });

    expect(result.user.id).toBe('user-9');
    expect(users.create).not.toHaveBeenCalled();
    expect(users.save).not.toHaveBeenCalled();
  });

  it('refuses to attach Google to an account that has a password', async () => {
    const { service, users, existing } = makeService();
    existing({
      id: 'user-2',
      email: 'traveler@example.com',
      googleId: null,
      passwordHash: '$2a$10$abcdefghijklmnopqrstuv',
      isActive: true,
    });

    await expect(service.loginWithGoogle({ idToken: 'token' })).rejects.toBeInstanceOf(
      ConflictException,
    );
    expect(users.save).not.toHaveBeenCalled();
  });

  it('rejects an inactive account', async () => {
    const { service, existing } = makeService();
    existing({
      id: 'user-3',
      email: 'traveler@example.com',
      googleId: 'google-sub-1',
      passwordHash: null,
      isActive: false,
    });

    await expect(service.loginWithGoogle({ idToken: 'token' })).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });

  it('propagates an unverifiable token as 401', async () => {
    const { service, verifier } = makeService();
    verifier.verify.mockRejectedValueOnce(
      new UnauthorizedException('Invalid Google credential.'),
    );

    await expect(service.loginWithGoogle({ idToken: 'forged' })).rejects.toThrow(
      'Invalid Google credential.',
    );
  });
});

describe('GoogleTokenVerifier', () => {
  const verifierWith = (clientIds: string[], client: unknown) => {
    const config = {
      get: jest.fn((key: string) =>
        key === 'google.clientIds' ? clientIds : undefined,
      ),
    };
    const verifier = new GoogleTokenVerifier(config as unknown as ConfigService);
    // The OAuth2Client is created internally; swap it for a stub here.
    (verifier as unknown as Record<string, unknown>).client = client;
    return verifier;
  };

  it('fails closed when no audience is configured', async () => {
    const verifier = verifierWith([], { verifyIdToken: jest.fn() });

    await expect(verifier.verify('token')).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('verifies against the configured audience and normalises the claims', async () => {
    const verifyIdToken = jest.fn(async () => ({
      getPayload: () => ({
        sub: 'google-sub-1',
        email: '  Traveler@Example.COM ',
        email_verified: true,
        name: 'Nour',
        picture: 'https://example.com/a.png',
      }),
    }));
    const verifier = verifierWith(['web-client-id'], { verifyIdToken });

    const profile = await verifier.verify('token');

    expect(verifyIdToken).toHaveBeenCalledWith({
      idToken: 'token',
      audience: 'web-client-id',
    });
    expect(profile.email).toBe('traveler@example.com');
    expect(profile.subject).toBe('google-sub-1');
    expect(profile.emailVerified).toBe(true);
  });

  it('accepts several audiences', async () => {
    const verifyIdToken = jest.fn(async () => ({ getPayload: () => ({}) }));
    const verifier = verifierWith(['a', 'b'], { verifyIdToken });

    await expect(verifier.verify('token')).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
    expect(verifyIdToken).toHaveBeenCalledWith({
      idToken: 'token',
      audience: ['a', 'b'],
    });
  });

  it('rejects a token the library cannot verify', async () => {
    const verifier = verifierWith(['web-client-id'], {
      verifyIdToken: jest.fn(async () => {
        throw new Error('Wrong recipient, payload audience != requiredAudience');
      }),
    });

    await expect(verifier.verify('forged')).rejects.toThrow(
      'Invalid Google credential.',
    );
  });

  it('rejects a payload without a subject or email', async () => {
    const verifier = verifierWith(['web-client-id'], {
      verifyIdToken: jest.fn(async () => ({ getPayload: () => ({ email: 'a@b.c' }) })),
    });

    await expect(verifier.verify('token')).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });
});
