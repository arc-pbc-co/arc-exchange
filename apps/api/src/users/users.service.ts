import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../common/prisma/prisma.service';
import { KycStatus } from '@prisma/client';

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  async findByWallet(walletAddress: string) {
    const user = await this.prisma.user.findUnique({
      where: { walletAddress: walletAddress.toLowerCase() },
      include: {
        kycVerification: true,
        investments: {
          include: {
            pool: true,
          },
        },
      },
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    return user;
  }

  async updateEmail(userId: string, email: string) {
    return this.prisma.user.update({
      where: { id: userId },
      data: { email },
    });
  }

  async initiateKyc(userId: string, provider: string, externalId: string) {
    return this.prisma.kycVerification.upsert({
      where: { userId },
      create: {
        userId,
        provider,
        externalId,
        status: KycStatus.IN_PROGRESS,
      },
      update: {
        provider,
        externalId,
        status: KycStatus.IN_PROGRESS,
      },
    });
  }

  async updateKycStatus(
    userId: string,
    status: KycStatus,
    isAccredited: boolean,
    isUsPerson: boolean,
    rawResponse?: any,
  ) {
    return this.prisma.kycVerification.update({
      where: { userId },
      data: {
        status,
        isAccredited,
        isUsPerson,
        verifiedAt: status === KycStatus.APPROVED ? new Date() : null,
        expiresAt:
          status === KycStatus.APPROVED
            ? new Date(Date.now() + 365 * 24 * 60 * 60 * 1000) // 1 year
            : null,
        rawResponse,
      },
    });
  }

  async getKycStatus(userId: string) {
    const verification = await this.prisma.kycVerification.findUnique({
      where: { userId },
    });

    return {
      status: verification?.status ?? null,
      isAccredited: verification?.isAccredited ?? false,
      isUsPerson: verification?.isUsPerson ?? false,
      verifiedAt: verification?.verifiedAt ?? null,
      expiresAt: verification?.expiresAt ?? null,
    };
  }
}
