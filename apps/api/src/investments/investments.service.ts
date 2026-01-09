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
      orderBy: { purchasedAt: 'desc' },
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
    const purchasePriceUsd = pool.pricePerToken.mul(Number(tokenAmount));

    // Check if pool would exceed target
    const newTotal = pool.currentRaise.add(purchasePriceUsd);
    if (newTotal.gt(pool.targetRaise)) {
      throw new BadRequestException('Investment would exceed pool target raise');
    }

    // Create investment record
    const investment = await this.prisma.investment.create({
      data: {
        userId,
        poolId: dto.poolId,
        tokenAmount,
        purchasePriceUsd,
        txHash: dto.txHash,
      },
      include: {
        pool: true,
      },
    });

    // Update pool raised amount
    await this.poolsService.updateRaisedAmount(dto.poolId, Number(purchasePriceUsd));

    return investment;
  }

  async recordTransaction(investmentId: string, txHash: string) {
    return this.prisma.investment.update({
      where: { id: investmentId },
      data: { txHash },
    });
  }

  async getPortfolioSummary(userId: string) {
    const investments = await this.findByUser(userId);

    const totalInvested = investments.reduce(
      (sum, inv) => sum + Number(inv.purchasePriceUsd),
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
        purchasePriceUsd: Number(inv.purchasePriceUsd),
        yieldRate: Number(inv.pool.yieldRate),
        purchasedAt: inv.purchasedAt,
      })),
    };
  }
}
