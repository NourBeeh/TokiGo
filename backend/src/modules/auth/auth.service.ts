import {
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcryptjs';
import * as crypto from 'crypto';
import { GoogleLoginDto, LoginDto, RegisterDto, UpdateProfileDto } from '../../common/dto/auth.dto';
import { User } from '../../database/entities/user.entity';
import { Session } from '../../database/entities/session.entity';
import { GoogleProfile, GoogleTokenVerifier } from './google-token.verifier';

const BCRYPT_COST = 10;

const hashToken = (token: string) => crypto.createHash('sha256').update(token).digest('hex');

const parseDurationMs = (value: string): number => {
  const match = /^(\d+)\s*(ms|s|m|h|d)$/.exec(value.trim());
  if (!match) return 7 * 24 * 60 * 60 * 1000;
  const amount = Number(match[1]);
  const unit = match[2];
  const factor =
    unit === 'ms' ? 1 :
    unit === 's' ? 1000 :
    unit === 'm' ? 60 * 1000 :
    unit === 'h' ? 60 * 60 * 1000 :
    24 * 60 * 60 * 1000;
  return amount * factor;
};

@Injectable()
export class AuthService {
  constructor(
    private jwtService: JwtService,
    private config: ConfigService,
    @InjectRepository(User)
    private readonly users: Repository<User>,
    @InjectRepository(Session)
    private readonly sessions: Repository<Session>,
    private readonly googleVerifier: GoogleTokenVerifier,
  ) {}

  async register(dto: RegisterDto) {
    const existing = await this.users.findOne({ where: { email: dto.email } });
    if (existing) {
      throw new ConflictException('An account with this email already exists.');
    }

    const passwordHash = await bcrypt.hash(dto.password, BCRYPT_COST);
    const user = this.users.create({
      email: dto.email,
      displayName: dto.displayName,
      passwordHash,
      isActive: true,
    });
    await this.users.save(user);

    return this.issueTokens(user);
  }

  async login(dto: LoginDto) {
    // passwordHash is select:false on the entity, so pull it explicitly.
    const user = await this.users
      .createQueryBuilder('user')
      .addSelect('user.passwordHash')
      .where('user.email = :email', { email: dto.email })
      .getOne();

    const genericError = new UnauthorizedException(
      'Invalid email or password.',
    );

    if (!user || !user.passwordHash) {
      // Same message for unknown user and wrong password.
      throw genericError;
    }

    const matches = await bcrypt.compare(dto.password, user.passwordHash);
    if (!matches) {
      throw genericError;
    }

    if (!user.isActive) {
      throw new UnauthorizedException('This account is not active.');
    }

    return this.issueTokens(user);
  }

  /// Sign in with a Google ID token.
  ///
  /// The token is verified server-side (signature, issuer, audience, expiry)
  /// before anything is trusted — the client sends proof of identity, never a
  /// profile, and the claims are read from the verified token.
  async loginWithGoogle(dto: GoogleLoginDto) {
    const profile = await this.googleVerifier.verify(dto.idToken);

    if (!profile.emailVerified) {
      throw new UnauthorizedException(
        'This Google account has no verified email.',
      );
    }

    const user = await this.findForGoogle(profile);
    if (!user) {
      return this.createGoogleUser(profile);
    }

    if (!user.isActive) {
      throw new UnauthorizedException('This account is not active.');
    }

    if (user.passwordHash) {
      // Refuse to attach Google to a password account: without verified
      // passwords/emails, merging the two would let whoever registered that
      // address first keep a working credential on the account.
      throw new ConflictException(
        'An account with this email already uses a password.',
      );
    }

    if (user.email !== profile.email) {
      // Google changed its primary address; keep the local copy in step.
      user.email = profile.email;
      await this.users.save(user);
    }

    if (!user.avatarUrl && profile.pictureUrl) {
      user.avatarUrl = profile.pictureUrl;
      await this.users.save(user);
    }

    return this.issueTokens(user);
  }

  /// Finds an account for a Google identity by linked Google id or by email
  /// (case-insensitive). `passwordHash` is selected explicitly so the caller
  /// can tell a Google-only account from a password one; it is never returned.
  private findForGoogle(profile: GoogleProfile): Promise<User | null> {
    return this.users
      .createQueryBuilder('user')
      .addSelect('user.passwordHash')
      .where('user.googleId = :subject', { subject: profile.subject })
      .orWhere('LOWER(user.email) = :email', { email: profile.email })
      .getOne();
  }

  private async createGoogleUser(profile: GoogleProfile) {
    const user = this.users.create({
      email: profile.email,
      displayName: profile.displayName ?? profile.email.split('@')[0],
      googleId: profile.subject,
      avatarUrl: profile.pictureUrl ?? undefined,
      isActive: true,
    });

    try {
      const saved = await this.users.save(user);
      return this.issueTokens(saved);
    } catch (error) {
      // Concurrent first sign-ins can race on the unique email index; the
      // loser reuses the row the winner created instead of failing.
      const raced = await this.findForGoogle(profile);
      if (raced?.isActive) {
        return this.issueTokens(raced);
      }
      throw error;
    }
  }

  async me(userId: string) {
    const user = await this.users.findOne({ where: { id: userId } });
    if (!user || !user.isActive) {
      throw new UnauthorizedException('Authentication required.');
    }
    return this.toPublicUser(user);
  }

  async updateProfile(userId: string, dto: UpdateProfileDto) {
    const user = await this.users.findOne({ where: { id: userId } });
    if (!user || !user.isActive) {
      throw new UnauthorizedException('Authentication required.');
    }
    if (dto.displayName !== undefined) user.displayName = dto.displayName ?? undefined;
    if (dto.title !== undefined) user.title = dto.title ?? undefined;
    if (dto.firstName !== undefined) user.firstName = dto.firstName ?? undefined;
    if (dto.middleName !== undefined) user.middleName = dto.middleName ?? undefined;
    if (dto.lastName !== undefined) user.lastName = dto.lastName ?? undefined;
    if (dto.dateOfBirth !== undefined) {
      user.dateOfBirth = dto.dateOfBirth
        ? (new Date(dto.dateOfBirth) as any)
        : undefined;
    }
    if (dto.gender !== undefined) user.gender = dto.gender ?? undefined;
    if (dto.nationality !== undefined) user.nationality = dto.nationality ?? undefined;
    if (dto.avatarUrl !== undefined) user.avatarUrl = dto.avatarUrl ?? undefined;
    if (dto.phoneNumber !== undefined) user.phoneNumber = dto.phoneNumber ?? undefined;
    // Keep displayName in sync when first/last provided and displayName empty.
    if (!user.displayName && (user.firstName || user.lastName)) {
      user.displayName = [user.firstName, user.middleName, user.lastName]
        .filter(Boolean)
        .join(' ');
    }
    const saved = await this.users.save(user);
    return this.toPublicUser(saved);
  }

  async refresh(refreshToken: string) {
    try {
      const payload = await this.jwtService.verifyAsync(refreshToken, {
        secret:
                  this.config.get<string>('jwt.refreshSecret'),
      });
      const user = await this.users.findOne({
        where: { id: payload.sub },
      });
      if (!user || !user.isActive) {
        return { error: 'Invalid refresh token' };
      }

      const refreshTokenHash = hashToken(refreshToken);
      const session = await this.sessions.findOne({
        where: {
          userId: user.id,
          refreshTokenHash,
          isActive: true,
        },
      });
      if (!session) {
        return { error: 'Invalid refresh token' };
      }

      const accessToken = await this.jwtService.signAsync(
        { sub: user.id, email: user.email },
        {
          expiresIn: this.config.get('jwt.accessExpiresIn') ?? '15m',
        },
      );
      const newRefreshToken = await this.jwtService.signAsync(
        { sub: user.id, email: user.email },
        {
          secret: this.config.get<string>('jwt.refreshSecret'),
          expiresIn: this.config.get('jwt.refreshExpiresIn') ?? '7d',
        },
      );
      await this.sessions.update(session.id, {
        accessTokenHash: hashToken(accessToken),
        refreshTokenHash: hashToken(newRefreshToken),
      });
      return { accessToken, refreshToken: newRefreshToken };
    } catch {
      return { error: 'Invalid refresh token' };
    }
  }

  async logout(refreshToken: string) {
    try {
      const payload = await this.jwtService.verifyAsync(refreshToken, {
        secret: this.config.get<string>('jwt.refreshSecret'),
      });
      const refreshTokenHash = hashToken(refreshToken);
      await this.sessions.update(
        { userId: payload.sub, refreshTokenHash, isActive: true },
        { isActive: false },
      );
    } catch {
      // Best-effort revocation: even if we can't verify the token, succeed.
    }
    return { success: true };
  }

  private async issueTokens(user: User) {
    const payload = { sub: user.id, email: user.email };
    const accessExpires = this.config.get('jwt.accessExpiresIn') ?? '15m';
    const refreshExpires = this.config.get('jwt.refreshExpiresIn') ?? '7d';
    const accessToken = await this.jwtService.signAsync(payload, {
      expiresIn: accessExpires,
    });
    const refreshToken = await this.jwtService.signAsync(payload, {
      secret: this.config.get<string>('jwt.refreshSecret'),
      expiresIn: refreshExpires,
    });
    const expiresAt = new Date(Date.now() + parseDurationMs(refreshExpires));
    await this.sessions.save(
      this.sessions.create({
        userId: user.id,
        accessTokenHash: hashToken(accessToken),
        refreshTokenHash: hashToken(refreshToken),
        isActive: true,
        expiresAt,
      }),
    );
    return { user: this.toPublicUser(user), accessToken, refreshToken };
  }

  private toPublicUser(user: User) {
    // `role` was added in the admin workstream so clients can gate admin UI
    // (Flutter AuthUser.isAdmin). Defaulted so legacy rows/guests resolve.
    return {
      id: user.id,
      email: user.email,
      displayName: user.displayName ?? null,
      title: user.title ?? null,
      firstName: user.firstName ?? null,
      middleName: user.middleName ?? null,
      lastName: user.lastName ?? null,
      dateOfBirth: user.dateOfBirth ?? null,
      gender: user.gender ?? null,
      nationality: user.nationality ?? null,
      avatarUrl: user.avatarUrl ?? null,
      phoneNumber: user.phoneNumber ?? null,
      role: user.role ?? 'user',
    };
  }
}
