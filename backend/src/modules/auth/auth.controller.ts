import {
  Body,
  Controller,
  Get,
  Post,
  Request,
  UseGuards,
} from '@nestjs/common';
import { AuthService } from './auth.service';
import { LoginDto, RegisterDto } from '../../common/dto/auth.dto';
import { JwtAuthGuard } from './jwt-auth.guard';

interface AuthenticatedRequest {
  user: { id: string; email: string; displayName?: string };
}

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  async register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @Post('login')
  async login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  async me(@Request() req: AuthenticatedRequest) {
    // req.user comes from JwtStrategy.validate (full DB lookup).
    const user = await this.authService.me(req.user.id);
    return { user };
  }

  @Post('refresh')
  async refresh(@Body() body: { refreshToken: string }) {
    return this.authService.refresh(body?.refreshToken);
  }

  @Post('logout')
  async logout(@Body() body: { refreshToken: string }) {
    return this.authService.logout(body?.refreshToken);
  }

  @Get('session')
  async session() {
    return { valid: true };
  }
}
