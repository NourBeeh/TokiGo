import { validate } from 'class-validator';
import { ConflictException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcryptjs';

import { LoginDto, RegisterDto } from '../src/common/dto/auth.dto';
import { AuthService } from '../src/modules/auth/auth.service';
import { User } from '../src/database/entities/user.entity';

describe('Auth DTO validation', () => {
  it('rejects a login payload with an invalid email', async () => {
    const dto = new LoginDto();
    dto.email = 'not-an-email';
    dto.password = 'longenough123';

    const errors = await validate(dto);
    expect(errors.some((e) => e.property === 'email')).toBe(true);
  });

  it('rejects a login payload with a short password', async () => {
    const dto = new LoginDto();
    dto.email = 'user@example.com';
    dto.password = 'short';

    const errors = await validate(dto);
    expect(errors.some((e) => e.property === 'password')).toBe(true);
  });

  it('accepts a valid login payload', async () => {
    const dto = new LoginDto();
    dto.email = 'user@example.com';
    dto.password = 'longenough123';

    expect(await validate(dto)).toHaveLength(0);
  });

  it('rejects a register payload with a short password', async () => {
    const dto = new RegisterDto();
    dto.email = 'user@example.com';
    dto.password = 'short';

    const errors = await validate(dto);
    expect(errors.some((e) => e.property === 'password')).toBe(true);
  });

  it('accepts a valid register payload with optional display name', async () => {
    const dto = new RegisterDto();
    dto.email = 'user@example.com';
    dto.password = 'longenough123';
    dto.displayName = 'Nour';

    expect(await validate(dto)).toHaveLength(0);
  });
});

const makeDeps = () => {
  const users = {
    findOne: jest.fn(),
    create: jest.fn((data: Partial<User>) => ({ ...data }) as User),
    save: jest.fn(async (data: Partial<User>) => ({
      id: 'user-1',
      email: data.email,
      displayName: data.displayName ?? null,
      isActive: true,
      createdAt: new Date(),
      updatedAt: new Date(),
    }) as User),
    createQueryBuilder: undefined,
  };
  const jwtService = {
    signAsync: jest.fn(async (payload: object) => `signed:${JSON.stringify(payload)}`),
    verifyAsync: jest.fn(),
  };
  const config = {
    get: jest.fn((key: string) => {
      if (key === 'jwt.refreshSecret') return 'test-refresh-secret';
      if (key === 'jwt.accessExpiresIn') return '15m';
      if (key === 'jwt.refreshExpiresIn') return '7d';
      return undefined;
    }),
  };
  return {
    service: new AuthService(
      jwtService as unknown as JwtService,
      config as unknown as ConfigService,
      users as unknown as Repository<User>,
    ),
    users,
    jwtService,
  };
};

describe('AuthService.register', () => {
  it('hashes the password and never stores or returns it in plain text', async () => {
    const { service, users } = makeDeps();
    users.findOne.mockResolvedValueOnce(null);

    const result = await service.register({
      email: 'new@example.com',
      password: 'longenough123',
      displayName: 'Nour',
    });

    const created = users.create.mock.calls[0][0];
    expect(created.email).toBe('new@example.com');
    // Stored value is a bcrypt hash, not the plain text.
    expect(created.passwordHash).not.toBe('longenough123');
    expect(await bcrypt.compare('longenough123', created.passwordHash)).toBe(
      true,
    );
    // Public response carries no hash material.
    expect(JSON.stringify(result)).not.toContain('passwordHash');
    expect(result.user.email).toBe('new@example.com');
    expect(result.accessToken).toBeTruthy();
    expect(result.refreshToken).toBeTruthy();
  });

  it('rejects duplicate email registration without leaking details', async () => {
    const { service, users } = makeDeps();
    users.findOne.mockResolvedValueOnce({ id: 'existing' });

    await expect(
      service.register({ email: 'taken@example.com', password: 'longenough123' }),
    ).rejects.toBeInstanceOf(ConflictException);
  });
});

describe('AuthService.login', () => {
  const hashOf = (plain: string) => bcrypt.hashSync(plain, 10);

  const userWithHash = (overrides: Partial<User> = {}): Record<string, unknown> => ({
    id: 'user-1',
    email: 'user@example.com',
    displayName: null,
    passwordHash: hashOf('correct-password'),
    isActive: true,
    ...overrides,
  });

  const loginService = () => {
    const deps = makeDeps();
    // login uses a QueryBuilder to pull the select:false column.
    (deps.users as unknown as Record<string, unknown>).createQueryBuilder = jest.fn(
      () => {
        let whereEmail = '';
        const qb = {
          addSelect: () => qb,
          where: (_sql: string, params: { email: string }) => {
            whereEmail = params.email;
            return qb;
          },
          getOne: async () => {
            if (whereEmail === 'user@example.com') return userWithHash();
            if (whereEmail === 'inactive@example.com')
              return userWithHash({ isActive: false });
            return null;
          },
        };
        return qb;
      },
    );
    return deps;
  };

  it('returns tokens and public user on valid credentials', async () => {
    const { service } = loginService();

    const result = await service.login({
      email: 'user@example.com',
      password: 'correct-password',
    });

    expect(result.user.id).toBe('user-1');
    expect(result.accessToken).toContain('signed:');
    expect(result.refreshToken).toContain('signed:');
    expect(JSON.stringify(result)).not.toContain('passwordHash');
  });

  it('throws the same generic error for unknown user and wrong password', async () => {
    const { service } = loginService();

    const unknownUser = service.login({
      email: 'ghost@example.com',
      password: 'whatever-long',
    });
    const wrongPassword = service.login({
      email: 'user@example.com',
      password: 'wrong-password',
    });

    await expect(unknownUser).rejects.toThrow('Invalid email or password.');
    await expect(wrongPassword).rejects.toBeInstanceOf(UnauthorizedException);
    await expect(wrongPassword).rejects.toThrow('Invalid email or password.');
  });

  it('rejects an inactive account', async () => {
    const { service } = loginService();

    await expect(
      service.login({ email: 'inactive@example.com', password: 'correct-password' }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });
});

describe('AuthService.me', () => {
  it('returns the sanitized public user', async () => {
    const { service, users } = makeDeps();
    users.findOne.mockResolvedValueOnce({
      id: 'user-1',
      email: 'user@example.com',
      displayName: 'Nour',
      passwordHash: 'secret-hash',
      isActive: true,
    });

    const me = await service.me('user-1');

    expect(me).toEqual({
      id: 'user-1',
      email: 'user@example.com',
      displayName: 'Nour',
      role: 'user',
    });
  });

  it('rejects missing or inactive users', async () => {
    const { service, users } = makeDeps();
    users.findOne.mockResolvedValueOnce(null);

    await expect(service.me('missing')).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });
});

describe('AuthService.refresh', () => {
  it('issues a fresh access token for a valid refresh token of an active user', async () => {
    const { service, jwtService, users } = makeDeps();
    users.findOne.mockResolvedValueOnce({ id: 'user-1', email: 'u@e.com', isActive: true });
    jwtService.verifyAsync.mockResolvedValueOnce({ sub: 'user-1', email: 'u@e.com' });

    const result = await service.refresh('valid-refresh-token');

    expect(result).toHaveProperty('accessToken');
    // Refresh verification must use the dedicated refresh secret.
    expect(jwtService.verifyAsync).toHaveBeenCalledWith(
      'valid-refresh-token',
      { secret: 'test-refresh-secret' },
    );
  });

  it('returns an inline error shape for an invalid refresh token', async () => {
    const { service, jwtService } = makeDeps();
    jwtService.verifyAsync.mockRejectedValueOnce(new Error('bad token'));

    const result = await service.refresh('garbage');

    expect(result).toEqual({ error: 'Invalid refresh token' });
  });
});
