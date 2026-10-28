import { SetMetadata } from '@nestjs/common';

export const ROLES_KEY = 'roles';

/** Route-level role requirement, consumed by RolesGuard. */
export const Roles = (...roles: string[]) => SetMetadata(ROLES_KEY, roles);
