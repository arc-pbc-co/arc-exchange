import { Controller, Get, Patch, Body, UseGuards, Request } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { UsersService } from './users.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { UpdateEmailDto } from './users.dto';

@ApiTags('users')
@Controller('users')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class UsersController {
  constructor(private usersService: UsersService) {}

  @Get('profile')
  @ApiOperation({ summary: 'Get current user profile with investments' })
  async getProfile(@Request() req: any) {
    return this.usersService.findByWallet(req.user.walletAddress);
  }

  @Patch('email')
  @ApiOperation({ summary: 'Update user email' })
  async updateEmail(@Request() req: any, @Body() dto: UpdateEmailDto) {
    return this.usersService.updateEmail(req.user.sub, dto.email);
  }

  @Get('kyc')
  @ApiOperation({ summary: 'Get KYC verification status' })
  async getKycStatus(@Request() req: any) {
    return this.usersService.getKycStatus(req.user.sub);
  }
}
