import { Controller, Post, Body, Get, UseGuards, Request } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './jwt-auth.guard';
import { GetNonceDto, VerifySignatureDto } from './auth.dto';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Post('nonce')
  @ApiOperation({ summary: 'Generate a nonce for SIWE authentication' })
  async getNonce(@Body() dto: GetNonceDto) {
    const nonce = await this.authService.generateNonce(dto.walletAddress);
    return { nonce };
  }

  @Post('verify')
  @ApiOperation({ summary: 'Verify SIWE signature and get JWT token' })
  async verify(@Body() dto: VerifySignatureDto) {
    return this.authService.verifySignature(dto.message, dto.signature);
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get current authenticated user' })
  async getMe(@Request() req: any) {
    const user = await this.authService.validateUser(req.user.sub);
    return {
      id: user?.id,
      walletAddress: user?.walletAddress,
      email: user?.email,
      kycStatus: user?.kycVerification?.status ?? null,
      isAccredited: user?.kycVerification?.isAccredited ?? false,
      isUsPerson: user?.kycVerification?.isUsPerson ?? false,
    };
  }
}
