! This file is part of the Kestrel software for simulations
! of sediment-laden Earth surface flows.
!
! Version 1.0
!
! Copyright 2023 Mark J. Woodhouse, Jake Langham, (University of Bristol).
!
! This program is free software: you can redistribute it and/or modify it 
! under the terms of the GNU General Public License as published by the Free 
! Software Foundation, either version 3 of the License, or (at your option) 
! any later version.
!
! This program is distributed in the hope that it will be useful, but WITHOUT 
! ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
! FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for 
! more details.
!
! You should have received a copy of the GNU General Public License along with 
! this program. If not, see <https://www.gnu.org/licenses/>. 


! This module assigns values to variables in RunSet associated
! with the numerical solver, as read from the "Solver" block of an input file.
! Some input validation is performed, producing Warning or FatalError messages.
!
! The solver settings includes choice of slope limiter by pointing the generic
! limiter functions to specific implementations.  See Limiters.f90
module solver_settings_module

   use set_precision_module, only: wp
   use messages_module, only: FatalErrorMessage, InputLabelUnrecognized, WarningMessage
   use limiters_module
   use varstring_module, only: varString
   use runsettings_module, only: RunSet

   implicit none

   private
   public :: Solver_Set

! default values
   character(len=7), parameter :: limiter_d = 'MinMod2'
   procedure(limiter), pointer :: limiter_dfunc => MinMod2
   real(kind=wp) :: heightThreshold_d = 1e-6_wp
   integer :: TileBuffer_d = 3
   real(kind=wp) :: cfl_d = 0.25_wp
   real(kind=wp) :: maxdt_d = HUGE(1.0_wp)
   real(kind=wp), parameter :: tstart_d = 0.0_wp
   logical :: Restart_d = .FALSE.

contains

   ! Set solver settings from input file.
   ! Inputs: SolverLabels - Labels in the Solver block;
   !         SolverValues - The values associated with the labels.
   ! InOut: RunParams [type RunSet] - The solver settings.
   subroutine Solver_Set(SolverLabels,SolverValues,RunParams)
      type(VarString), dimension(:), intent(in) :: SolverLabels
      type(VarString), dimension(:), intent(in) :: SolverValues
      type(RunSet), intent(inout) :: RunParams

      type(varString) :: label
      type(varString) :: limiter_label
      type(varString) :: Restart_label

      integer :: J, N

      logical :: set_limiter
      logical :: set_heightThreshold
      logical :: set_SpongeStrength
      logical :: set_TileBuffer
      logical :: set_cfl
      logical :: set_maxdt
      logical :: set_tstart
      logical :: set_tend
      logical :: set_Restart
      logical :: set_InitialCondition

      N = size(SolverValues)

      set_limiter=.FALSE.
      set_heightThreshold=.FALSE.
      set_SpongeStrength=.FALSE.
      set_TileBuffer=.FALSE.
      set_cfl=.FALSE.
      set_maxdt=.FALSE.
      set_tstart=.FALSE.
      set_tend=.FALSE.
      set_Restart=.FALSE.
      set_InitialCondition=.FALSE.

      do J=1,N
         label = SolverLabels(J)%to_lower()
         select case (label%s)
            case ('limiter')
               set_limiter=.TRUE.
               limiter_label = SolverValues(J)%to_lower()
               select case (limiter_label%s)
                  case ('minmod1')
                     RunParams%limiter = varString('MinMod1')
                     limiter => MinMod1
                  case ('minmod2')
                     RunParams%limiter = varString('MinMod2')
                     limiter => MinMod2
                  case ('van albada', 'albada')
                     RunParams%limiter = varString('van Albada')
                     limiter => vanAlbada
                  case ('weno')
                     RunParams%limiter = varString('Weno')
                     limiter => WENO
                  case ('none')
                     RunParams%limiter = varString('None')
                     limiter => LimiterNone
                  case default
                     call WarningMessage("In the 'Solver' block the value of 'limiter' is not recognized.  " &
                        // "Using the default limiter = " // limiter_d)
                     RunParams%limiter = varString(limiter_d)
                     limiter => limiter_dfunc
               end select

            case ('height threshold')
               set_heightThreshold=.TRUE.
               RunParams%heightThreshold = SolverValues(J)%to_real()
               if (RunParams%heightThreshold.le.0.0_wp) then
                  call FatalErrorMessage("In the 'Solver' block in the input file "// trim(RunParams%InputFile%s) // new_line('A') &
                     // " The block variable 'Height threshold' must be positive.")
               end if

            case ('sponge strength')
               set_SpongeStrength=.TRUE.
               RunParams%SpongeLayer=.TRUE.
               RunParams%SpongeStrength = SolverValues(J)%to_real()
               if (RunParams%SpongeStrength.le.0) call FatalErrorMessage("In the 'Solver' block in the input file "// trim(RunParams%InputFile%s) // new_line('A') &
                  // " The block variable 'Sponge Strength' must be positive.")

            case ('tile buffer')
               set_TileBuffer=.TRUE.
               RunParams%TileBuffer = SolverValues(J)%to_int()
               if (RunParams%TileBuffer.le.1) call FatalErrorMessage("In the 'Solver' block in the input file "// trim(RunParams%InputFile%s) // new_line('A') &
                  // " The block variable 'Tile Buffer' must be greater than 1.")

            case ('cfl')
               set_cfl=.TRUE.
               RunParams%cfl = SolverValues(J)%to_real()
               if ((RunParams%cfl.le.0.0_wp).or.(RunParams%cfl>0.5_wp)) then
                  call FatalErrorMessage("In the 'Solver' block in the input file "// trim(RunParams%InputFile%s) // new_line('A') &
                     // " The block variable 'cfl' must be in the range (0,0.5].")
               end if

            case ('max dt')
               set_maxdt=.TRUE.
               RunParams%maxdt = SolverValues(J)%to_real()
               if (RunParams%maxdt.le.0.0_wp) then
                  call FatalErrorMessage("In the 'Solver' block in the input file "// trim(RunParams%InputFile%s) // new_line('A') &
                     // " The block variable 'max dt' must be positive.")
               end if

            case ('t start')
               set_tstart=.TRUE.
               RunParams%tstart = SolverValues(J)%to_real()

            case ('t end')
               set_tend=.TRUE.
               RunParams%tend = SolverValues(J)%to_real()

            case ('restart')
               set_Restart=.TRUE.
               Restart_label = SolverValues(J)%to_lower()
               select case (Restart_label%s)
                  case ('on')
                     RunParams%Restart = .TRUE.
                  case ('off')
                     RunParams%Restart = .FALSE.
                  case default
                     call WarningMessage("In the 'Solver' block the value of 'Restart' is not recognized. Using the default setting Restart = off.")
                     RunParams%Restart = Restart_d
                  end select
            
            case ('initial condition')
               set_InitialCondition = .true.
               RunParams%InitialCondition = SolverValues(J)
          
            case default
               call InputLabelUnrecognized(SolverLabels(J)%s)

         end select
      end do

      if (.not.set_limiter) then
         RunParams%limiter = varString(limiter_d)
         limiter => limiter_dfunc
      end if

      if (.not.set_heightThreshold) RunParams%heightThreshold = heightThreshold_d

      if (.not.set_SpongeStrength) RunParams%SpongeLayer = .FALSE.

      if (.not.set_TileBuffer) RunParams%TileBuffer = TileBuffer_d

      if (.not.set_cfl) RunParams%cfl = cfl_d

      if (.not.set_maxdt) RunParams%maxdt = maxdt_d

      if (.not.set_tstart) RunParams%tstart = tstart_d

      if (.not.set_tend) call FatalErrorMessage("In the 'Solver' block in the input file "// trim(RunParams%InputFile%s) // new_line('A') &
         // " The block variable 't end' must be specified.")

      if (.not. set_InitialCondition) RunParams%InitialCondition%s = " "

      if (RunParams%tstart>RunParams%tend) call FatalErrorMessage("In the 'Solver' block in the input file "// trim(RunParams%InputFile%s) // new_line('A') &
         // " The block variable 't end' must be greater than the block variable 't start'.")
        
      if (.not. set_Restart) RunParams%Restart = Restart_d

   end subroutine Solver_Set

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module solver_settings_module


