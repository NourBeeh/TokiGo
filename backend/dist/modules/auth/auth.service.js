"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthService = void 0;
const common_1 = require("@nestjs/common");
const jwt_1 = require("@nestjs/jwt");
const config_1 = require("@nestjs/config");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const bcrypt = __importStar(require("bcryptjs"));
const user_entity_1 = require("../../database/entities/user.entity");
const BCRYPT_COST = 10;
let AuthService = class AuthService {
    jwtService;
    config;
    users;
    constructor(jwtService, config, users) {
        this.jwtService = jwtService;
        this.config = config;
        this.users = users;
    }
    async register(dto) {
        const existing = await this.users.findOne({ where: { email: dto.email } });
        if (existing) {
            throw new common_1.ConflictException('An account with this email already exists.');
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
    async login(dto) {
        // passwordHash is select:false on the entity, so pull it explicitly.
        const user = await this.users
            .createQueryBuilder('user')
            .addSelect('user.passwordHash')
            .where('user.email = :email', { email: dto.email })
            .getOne();
        const genericError = new common_1.UnauthorizedException('Invalid email or password.');
        if (!user || !user.passwordHash) {
            // Same message for unknown user and wrong password.
            throw genericError;
        }
        const matches = await bcrypt.compare(dto.password, user.passwordHash);
        if (!matches) {
            throw genericError;
        }
        if (!user.isActive) {
            throw new common_1.UnauthorizedException('This account is not active.');
        }
        return this.issueTokens(user);
    }
    async me(userId) {
        const user = await this.users.findOne({ where: { id: userId } });
        if (!user || !user.isActive) {
            throw new common_1.UnauthorizedException('Authentication required.');
        }
        return this.toPublicUser(user);
    }
    async refresh(refreshToken) {
        try {
            const payload = await this.jwtService.verifyAsync(refreshToken, {
                secret: this.config.get('jwt.refreshSecret') ?? 'dev-refresh-secret',
            });
            const user = await this.users.findOne({
                where: { id: payload.sub },
            });
            if (!user || !user.isActive) {
                return { error: 'Invalid refresh token' };
            }
            const accessToken = await this.jwtService.signAsync({ sub: user.id, email: user.email }, {
                expiresIn: this.config.get('jwt.accessExpiresIn') ?? '15m',
            });
            return { accessToken };
        }
        catch {
            return { error: 'Invalid refresh token' };
        }
    }
    async logout(_refreshToken) {
        // Client-side token clearing only in Phase 17; server-side session
        // revocation is deferred until the Sessions table is activated.
        return { success: true };
    }
    async issueTokens(user) {
        const payload = { sub: user.id, email: user.email };
        const accessExpires = this.config.get('jwt.accessExpiresIn') ?? '15m';
        const refreshExpires = this.config.get('jwt.refreshExpiresIn') ?? '7d';
        const accessToken = await this.jwtService.signAsync(payload, {
            expiresIn: accessExpires,
        });
        const refreshToken = await this.jwtService.signAsync(payload, {
            secret: this.config.get('jwt.refreshSecret') ?? 'dev-refresh-secret',
            expiresIn: refreshExpires,
        });
        return { user: this.toPublicUser(user), accessToken, refreshToken };
    }
    toPublicUser(user) {
        // `role` was added in the admin workstream so clients can gate admin UI
        // (Flutter AuthUser.isAdmin). Defaulted so legacy rows/guests resolve.
        return {
            id: user.id,
            email: user.email,
            displayName: user.displayName ?? null,
            role: user.role ?? 'user',
        };
    }
};
exports.AuthService = AuthService;
exports.AuthService = AuthService = __decorate([
    (0, common_1.Injectable)(),
    __param(2, (0, typeorm_1.InjectRepository)(user_entity_1.User)),
    __metadata("design:paramtypes", [jwt_1.JwtService,
        config_1.ConfigService,
        typeorm_2.Repository])
], AuthService);
//# sourceMappingURL=auth.service.js.map