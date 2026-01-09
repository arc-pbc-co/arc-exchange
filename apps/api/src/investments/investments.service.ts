import { Injectable, BadRequestException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../common/prisma/prisma.service';
import { PoolsService } from '../pools/pools.service';
import { PoolStatus } from '@prisma/client';
import { CreateInvestmentDto } from './investments.dto';

@Injectable()
export class InvestmentsService {
  constructor(
    private prisma: PrismaService,
    private poolsService: PoolsService,
  ) {}

  async findByUser(userId: string) {
    return this.prisma.investment.findMany({
      where: { userId },
      include: {
        pool: true,
        claims: {
          include: {
            distribution: true,
          },
        },
      },
      orderBy: { firstPurchasedAt: 'desc' },
    });
  }

  async create(userId: string, dto: CreateInvestmentDto, isAccredited: boolean) {
    // Verify user is accredited
    if (!isAccredited) {
      throw new ForbiddenException('Only accredited investors can invest');
    }

    // Get pool and validate
    const pool = await this.poolsService.findById(dto.poolId);

    if (pool.status !== PoolStatus.ACTIVE) {
      throw new BadRequestException('Pool is not currently accepting investments');
    }

    // Calculate investment amount
    const tokenAmount = BigInt(dto.tokenAmount);
    const totalInvestedUsd = pool.pricePerToken.mul(Number(tokenAmount));

    // Check if pool would exceed target
    const newTotal = pool.currentRaise.add(totalInvestedUsd);
    if (newTotal.gt(pool.targetRaise)) {
      throw new BadRequestException('Investment would exceed pool target raise');
    }

    const now = new Date();

    // Create or update investment record
    const investment = await this.prisma.investment.upsert({
      where: {
        userId_poolId: {
          userId,
          poolId: dto.poolId,
        },
      },
      create: {
        userId,
        poolId: dto.poolId,
        tokenAmount,
        totalInvestedUsd,
        averagePriceUsd: pool.pricePerToken,
        firstPurchasedAt: now,
        lastPurchasedAt: now,
      },
      update: {
        tokenAmount: {
          increment: tokenAmount,
        },
        totalInvestedUsd: {
          increment: totalInvestedUsd,
        },
        lastPurchasedAt: now,
      },
      include: {
        pool: true,
      },
    });

    // Update pool raised amount
    await this.poolsService.updateRaisedAmount(dto.poolId, Number(totalInvestedUsd));

    return investment;
  }

  async getPortfolioSummary(userId: string) {
    const investments = await this.findByUser(userId);

    const totalInvested = investments.reduce(
      (sum, inv) => sum + Number(inv.totalInvestedUsd),
      0,
    );

    const totalTokens = investments.reduce(
      (sum, inv) => sum + Number(inv.tokenAmount),
      0,
    );

    const poolsInvested = new Set(investments.map((inv) => inv.poolId)).size;

    return {
      totalInvested,
      totalTokens,
      poolsInvested,
      investments: investments.map((inv) => ({
        id: inv.id,
        poolName: inv.pool.name,
        poolSector: inv.pool.sector,
        tokenAmount: inv.tokenAmount.toString(),
        totalInvestedUsd: Number(inv.totalInvestedUsd),
        yieldRate: Number(inv.pool.yieldRate),
        firstPurchasedAt: inv.firstPurchasedAt,
      })),
    };
  }
}
