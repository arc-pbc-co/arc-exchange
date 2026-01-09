import {
  IsString,
  IsNumber,
  IsOptional,
  IsDateString,
  IsEnum,
  Min,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { PoolStatus } from '@prisma/client';

export class CreatePoolDto {
  @ApiProperty({ description: 'Pool name' })
  @IsString()
  name: string;

  @ApiProperty({ description: 'Pool description' })
  @IsString()
  description: string;

  @ApiProperty({ description: 'Investment sector (e.g., Real Estate, Infrastructure)' })
  @IsString()
  sector: string;

  @ApiProperty({ description: 'Target raise amount in USD' })
  @IsNumber()
  @Min(0)
  targetRaise: number;

  @ApiProperty({ description: 'Expected yield rate as percentage (e.g., 8.5)' })
  @IsNumber()
  @Min(0)
  yieldRate: number;

  @ApiProperty({ description: 'Maturity date ISO string' })
  @IsDateString()
  maturityDate: string;

  @ApiProperty({ description: 'Price per token in USDC' })
  @IsNumber()
  @Min(0)
  pricePerToken: number;

  @ApiPropertyOptional({ description: 'Image URL for the pool' })
  @IsOptional()
  @IsString()
  imageUrl?: string;
}

export class UpdatePoolDto extends PartialType(CreatePoolDto) {
  @ApiPropertyOptional({ enum: PoolStatus, description: 'Pool status' })
  @IsOptional()
  @IsEnum(PoolStatus)
  status?: PoolStatus;

  @ApiPropertyOptional({ description: 'IPFS metadata URI' })
  @IsOptional()
  @IsString()
  metadataUri?: string;

  @ApiPropertyOptional({ description: 'ERC-1155 token ID on contract' })
  @IsOptional()
  @IsString()
  contractTokenId?: string;

  @ApiPropertyOptional({ description: 'Total token supply' })
  @IsOptional()
  @IsString()
  totalSupply?: string;
}
