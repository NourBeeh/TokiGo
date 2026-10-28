import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ROLES_KEY } from '../decorators/roles.decorator';

/**
 * Role gate used behind JwtAuthGuard. The JWT strategy already loads the full
 * user entity (including `role`) onto `request.user`, so this guard only
 * compares that role against the route's `@Roles(...)` metadata.
 *
 * Routes without role metadata pass through untouched.
 */
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<string[] | undefined>(
      ROLES_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!requiredRoles || requiredRoles.length === 0) {
      return true;
    }
    const request = context.switchToHttp().getRequest();
    const user = request.user as { role?: string } | undefined;
    if (!user?.role || !requiredRoles.includes(user.role)) {
      throw new ForbiddenException('Admin access required.');
    }
    return true;
  }
}
