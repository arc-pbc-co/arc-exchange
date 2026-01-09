import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { SiweMessage, generateNonce } from 'siwe';
import { PrismaService } from '../common/prisma/prisma.service';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
    private configService: ConfigService,
  ) {}

  async generateNonce(walletAddress?: string): Promise<string> {
    const nonce = generateNonce();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    // Find or create user if wallet provided
    let userId: string | undefined;
    if (walletAddress) {
      const user = await this.prisma.user.upsert({
        where: { walletAddress: walletAddress.toLowerCase() },
        update: {},
        create: { walletAddress: walletAddress.toLowerCase() },
      });
      userId = user.id;
    }

    await this.prisma.authNonce.create({
      data: {
        nonce,
        expiresAt,
        userId,
      },
    });

    return nonce;
  }

  async verifySignature(
    message: string,
    signature: string,
  ): Promise<{ accessToken: string; user: any }> {
    try {
      const siweMessage = new SiweMessage(message);
      const fields = await siweMessage.verify({ signature });

      if (!fields.success) {
        throw new UnauthorizedException('Invalid signature');
      }

      // Verify nonce exists and hasn't expired
      const nonceRecord = await this.prisma.authNonce.findUnique({
        where: { nonce: siweMessage.nonce },
      });

      if (!nonceRecord || nonceRecord.expiresAt < new Date()) {
        throw new UnauthorizedException('Invalid or expired nonce');
      }

      // Delete used nonce
      await this.prisma.authNonce.delete({
        where: { id: nonceRecord.id },
      });

      // Get or create user
      const walletAddress = siweMessage.address.toLowerCase();
      const user = await this.prisma.user.upsert({
        where: { walletAddress },
        update: {},
        create: { walletAddress },
        include: {
          kycVerification: true,
        },
      });

      // Generate JWT
      const payload = {
        sub: user.id,
        walletAddress: user.walletAddress,
        isVerified: user.kycVerification?.status === 'APPROVED',
        isAccredited: user.kycVerification?.isAccredited ?? false,
      };

      const accessToken = this.jwtService.sign(payload);

      return {
        accessToken,
        user: {
          id: user.id,
          walletAddress: user.walletAddress,
          email: user.email,
          kycStatus: user.kycVerification?.status ?? null,
          isAccredited: user.kycVerification?.isAccredited ?? false,
          isUsPerson: user.kycVerification?.isUsPerson ?? false,
        },
      };
    } catch (error) {
      if (error instanceof UnauthorizedException) {
        throw error;
      }
      throw new UnauthorizedException('Invalid signature');
    }
  }

  async validateUser(userId: string) {
    return this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        kycVerification: true,
      },
    });
  }
}
