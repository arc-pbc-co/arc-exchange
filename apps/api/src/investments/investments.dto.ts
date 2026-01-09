import { IsString, IsOptional } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateInvestmentDto {
  @ApiProperty({ description: 'Pool ID to invest in' })
  @IsString()
  poolId: string;

  @ApiProperty({ description: 'Number of tokens to purchase' })
  @IsString()
  tokenAmount: string;

  @ApiPropertyOptional({ description: 'Transaction hash if already executed on-chain' })
  @IsOptional()
  @IsString()
  txHash?: string;
}
