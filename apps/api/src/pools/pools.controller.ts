import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { PoolsService } from './pools.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreatePoolDto, UpdatePoolDto } from './pools.dto';
import { PoolStatus } from '@prisma/client';

@ApiTags('pools')
@Controller('pools')
export class PoolsController {
  constructor(private poolsService: PoolsService) {}

  @Get()
  @ApiOperation({ summary: 'Get all active pools (public)' })
  async getActivePools() {
    return this.poolsService.findActive();
  }

  @Get('admin')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get all pools with optional status filter (admin)' })
  @ApiQuery({ name: 'status', enum: PoolStatus, required: false })
  async getAllPools(@Query('status') status?: PoolStatus) {
    return this.poolsService.findAll(status);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get pool by ID' })
  async getPool(@Param('id') id: string) {
    return this.poolsService.findById(id);
  }

  @Post()
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create a new pool (admin)' })
  async createPool(@Body() dto: CreatePoolDto) {
    return this.poolsService.create(dto);
  }

  @Patch(':id')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update a pool (admin)' })
  async updatePool(@Param('id') id: string, @Body() dto: UpdatePoolDto) {
    return this.poolsService.update(id, dto);
  }

  @Post(':id/activate')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Activate a pool for investment (admin)' })
  async activatePool(@Param('id') id: string) {
    return this.poolsService.activate(id);
  }
}
