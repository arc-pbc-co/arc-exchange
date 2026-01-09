import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../common/prisma/prisma.service';
import { PoolStatus, Prisma } from '@prisma/client';
import { CreatePoolDto, UpdatePoolDto } from './pools.dto';

@Injectable()
export class PoolsService {
  constructor(private prisma: PrismaService) {}

  async findAll(status?: PoolStatus) {
    const where: Prisma.PoolWhereInput = status ? { status } : {};

    return this.prisma.pool.findMany({
      where,
      orderBy: { createdAt: 'desc' },
    });
  }

  async findActive() {
    return this.prisma.pool.findMany({
      where: {
        status: {
          in: [PoolStatus.ACTIVE, PoolStatus.FUNDED],
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findById(id: string) {
    const pool = await this.prisma.pool.findUnique({
      where: { id },
      include: {
        investments: {
          select: {
            id: true,
            tokenAmount: true,
            totalInvestedUsd: true,
            firstPurchasedAt: true,
          },
        },
        distributions: {
          orderBy: { distributionDate: 'desc' },
        },
      },
    });

    if (!pool) {
      throw new NotFoundException('Pool not found');
    }

    return pool;
  }

  async create(dto: CreatePoolDto) {
    return this.prisma.pool.create({
      data: {
        name: dto.name,
        description: dto.description,
        sector: dto.sector,
        targetRaise: dto.targetRaise,
        yieldRate: dto.yieldRate,
        maturityDate: new Date(dto.maturityDate),
        pricePerToken: dto.pricePerToken,
        imageUrl: dto.imageUrl,
        status: PoolStatus.DRAFT,
      },
    });
  }

  async update(id: string, dto: UpdatePoolDto) {
    const pool = await this.findById(id);

    return this.prisma.pool.update({
      where: { id: pool.id },
      data: {
        name: dto.name,
        description: dto.description,
        sector: dto.sector,
        targetRaise: dto.targetRaise,
        yieldRate: dto.yieldRate,
        maturityDate: dto.maturityDate ? new Date(dto.maturityDate) : undefined,
        pricePerToken: dto.pricePerToken,
        imageUrl: dto.imageUrl,
        status: dto.status,
        metadataUri: dto.metadataUri,
        contractTokenId: dto.contractTokenId ? BigInt(dto.contractTokenId) : undefined,
        totalSupply: dto.totalSupply ? BigInt(dto.totalSupply) : undefined,
      },
    });
  }

  async activate(id: string) {
    const pool = await this.findById(id);

    if (pool.status !== PoolStatus.DRAFT && pool.status !== PoolStatus.PENDING_REVIEW) {
      throw new Error('Pool cannot be activated from current status');
    }

    return this.prisma.pool.update({
      where: { id: pool.id },
      data: { status: PoolStatus.ACTIVE },
    });
  }

  async updateRaisedAmount(id: string, amount: number) {
    const pool = await this.findById(id);

    const newCurrentRaise = pool.currentRaise.add(amount);
    const isFunded = newCurrentRaise.gte(pool.targetRaise);

    return this.prisma.pool.update({
      where: { id: pool.id },
      data: {
        currentRaise: newCurrentRaise,
        status: isFunded ? PoolStatus.FUNDED : pool.status,
      },
    });
  }
}
