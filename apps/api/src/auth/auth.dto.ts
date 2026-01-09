import { IsString, IsOptional, IsEthereumAddress } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class GetNonceDto {
  @ApiPropertyOptional({ description: 'Wallet address to associate with nonce' })
  @IsOptional()
  @IsString()
  walletAddress?: string;
}

export class VerifySignatureDto {
  @ApiProperty({ description: 'SIWE message string' })
  @IsString()
  message: string;

  @ApiProperty({ description: 'Signature from wallet' })
  @IsString()
  signature: string;
}
