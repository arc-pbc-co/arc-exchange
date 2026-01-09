import { Controller, Get, Post, Body, UseGuards, Request } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { InvestmentsService } from './investments.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreateInvestmentDto } from './investments.dto';

@ApiTags('investments')
@Controller('investments')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class InvestmentsController {
  constructor(private investmentsService: InvestmentsService) {}

  @Get()
  @ApiOperation({ summary: 'Get all investments for current user' })
  async getMyInvestments(@Request() req: any) {
    return this.investmentsService.findByUser(req.user.sub);
  }

  @Get('portfolio')
  @ApiOperation({ summary: 'Get portfolio summary for current user' })
  async getPortfolioSummary(@Request() req: any) {
    return this.investmentsService.getPortfolioSummary(req.user.sub);
  }

  @Post()
  @ApiOperation({ summary: 'Create a new investment (requires accredited investor status)' })
  async createInvestment(@Request() req: any, @Body() dto: CreateInvestmentDto) {
    return this.investmentsService.create(
      req.user.sub,
      dto,
      req.user.isAccredited,
    );
  }
}
