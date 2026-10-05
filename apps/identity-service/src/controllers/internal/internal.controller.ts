import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ServiceAuthGuard } from '@taladelivery/auth';
import { NotFoundError } from '@taladelivery/common';
import { Role } from '@taladelivery/contracts';
import { UserService } from '../../services/user.service';
import { CreateUserInternalDto } from '../../dto/create-user-internal.dto';

/**
 * Service-to-service endpoints for identity (docs/internal-contracts.md §1.1).
 * Only reachable with X-Service-Token.
 */
@Controller('internal')
@UseGuards(ServiceAuthGuard)
export class IdentityInternalController {
  constructor(private readonly users: UserService) {}

  @Post('users')
  async createUser(@Body() dto: CreateUserInternalDto) {
    const user = await this.users.create({
      name: dto.name,
      email: dto.email,
      phone: dto.phone ?? null,
      password: dto.password,
      role: dto.role,
      status: dto.status,
    });
    return this.users.toUserSnapshot(user);
  }

  @Get('users/:id')
  async userById(@Param('id', ParseIntPipe) id: number) {
    const user = await this.users.findById(id);
    if (user === null) {
      throw new NotFoundError('User not found.');
    }
    return this.users.toUserSnapshot(user);
  }

  @Get('users/by-email/:email')
  async userByEmail(@Param('email') email: string) {
    const user = await this.users.findByEmail(email);
    if (user === null) {
      // Contract (§1.1) explicitly allows a null snapshot here.
      return null;
    }
    return this.users.toUserSnapshot(user);
  }

  @Get('users/batch')
  async usersBatch(@Query('ids') ids?: string) {
    const parsed = parseIds(ids);
    const users = await this.users.findByIds(parsed);
    return users.map((user) => this.users.toUserSnapshot(user));
  }

  @Get('admin/totals')
  async totals() {
    const customers = await this.users.countByRole(Role.Customer);
    return { customers };
  }

  @Get('admin/active-users')
  async activeAdmins() {
    const admins = await this.users.findActiveByRole(Role.PlatformAdmin);
    return admins.map((user) => this.users.toUserSnapshot(user));
  }
}

function parseIds(ids?: string): number[] {
  if (ids === undefined || ids === '') return [];
  return ids
    .split(',')
    .map((value) => Number.parseInt(value, 10))
    .filter((id) => Number.isInteger(id) && id > 0);
}
