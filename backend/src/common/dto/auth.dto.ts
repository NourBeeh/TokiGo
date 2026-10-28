import { IsEmail, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class LoginDto {
  @IsEmail({}, { message: 'A valid email address is required.' })
  email!: string;

  @IsString()
  @MinLength(8, { message: 'Password must be at least 8 characters.' })
  password!: string;
}

export class RegisterDto {
  @IsEmail({}, { message: 'A valid email address is required.' })
  email!: string;

  @IsString()
  @MinLength(8, { message: 'Password must be at least 8 characters.' })
  @MaxLength(72, { message: 'Password must be at most 72 characters.' })
  password!: string;

  @IsOptional()
  @IsString()
  @MaxLength(80, { message: 'Display name must be at most 80 characters.' })
  displayName?: string;
}
