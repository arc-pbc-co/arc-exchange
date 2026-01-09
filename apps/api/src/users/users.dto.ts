import { IsEmail } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class UpdateEmailDto {
  @ApiProperty({ description: 'User email address' })
  @IsEmail()
  email: string;
}
