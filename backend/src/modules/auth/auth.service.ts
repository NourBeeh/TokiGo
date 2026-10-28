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
import { LoginDto, RegisterDto } from '../../common/dto/auth.dto';
import { User } from '../../database/entities/user.entity';

const BCRYPT_COST = 10;

@Injectable()
export class AuthService {
  constructor(
    private jwtService: JwtService,
    private config: ConfigService,
    @InjectRepository(User)
    private readonly users: Repository<User>,
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

  async me(userId: string) {
    const user = await this.users.findOne({ where: { id: userId } });
    if (!user || !user.isActive) {
      throw new UnauthorizedException('Authentication required.');
    }
    return this.toPublicUser(user);
  }

  async refresh(refreshToken: string) {
    try {
      const payload = await this.jwtService.verifyAsync(refreshToken, {
        secret:
          this.config.get<string>('jwt.refreshSecret') ?? 'dev-refresh-secret',
      });
      const user = await this.users.findOne({
        where: { id: payload.sub },
      });
      if (!user || !user.isActive) {
        return { error: 'Invalid refresh token' };
      }
      const accessToken = await this.jwtService.signAsync(
        { sub: user.id, email: user.email },
        {
          expiresIn: this.config.get('jwt.accessExpiresIn') ?? '15m',
        },
      );
      return { accessToken };
    } catch {
      return { error: 'Invalid refresh token' };
    }
  }

  async logout(_refreshToken: string) {
    // Client-side token clearing only in Phase 17; server-side session
    // revocation is deferred until the Sessions table is activated.
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
      secret:
        this.config.get<string>('jwt.refreshSecret') ?? 'dev-refresh-secret',
      expiresIn: refreshExpires,
    });
    return { user: this.toPublicUser(user), accessToken, refreshToken };
  }

  private toPublicUser(user: User) {
    // `role` was added in the admin workstream so clients can gate admin UI
    // (Flutter AuthUser.isAdmin). Defaulted so legacy rows/guests resolve.
    return {
      id: user.id,
      email: user.email,
      displayName: user.displayName ?? null,
      role: user.role ?? 'user',
    };
  }
}
