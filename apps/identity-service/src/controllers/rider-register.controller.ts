import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { AppKeyGuard } from '@taladelivery/auth';
import { Message } from '@taladelivery/common';
import { RiderRegistrationService } from '../services/rider-registration.service';
import { RiderRegisterDto } from '../dto/rider-register.dto';

/**
 * POST /api/v1/rider/register (contracts §4): creates the rider user,
 * provisions the dispatch rider profile, and issues the token pair (201).
 */
@Controller('rider')
export class RiderRegisterController {
  constructor(private readonly registration: RiderRegistrationService) {}

  @Post('register')
  @UseGuards(AppKeyGuard)
  @Message('Rider application submitted. Please wait for admin approval.')
  async register(@Body() dto: RiderRegisterDto) {
    return this.registration.register(dto);
  }
}