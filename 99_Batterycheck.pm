#########################################################################
# Helper for readingsGroup BatteryStatus:
# reads the battery states of devices and
# calculates the battery state in percent (depending on device type) and
# stores it as reading in corresponding dummy device
sub BatteryStatusFunction($$)
{
  my ($Device, $Event)  = @_;
  my @BatteryType = split(/:/,$Event); # to distinguish between "battery" and "batteryLevel" devices
  my $Model = AttrVal($Device, "model", "undef"); # get the corresponding model type
  my $TYPE = InternalVal($Device, "TYPE", "undef"); # get the TYPE of the device
  my $ActBatLevel = 0.0;
  my $MinBatLevel = 0.0;
  my $RemainingVoltageQuater = 0.0; # for "calculating" the colors
  my $MaxBattery = 3.1; # two 1.5V batteries have a measured voltage of 3.1V or even 3.2V
  my @DeviceNameParts = split(/_/,$Device); # to filter out HM_ Devices from neighbor or test system or newly included ones
  my $SignalDevice = $Device . "_BatState";

###############################
# Here you can change the variables to fit your installation.
#
  my $text_now = "Die Batterien von $Device müssen JETZT gewechselt werden!"; #Text for changing battery now
  my $text_soon = "Die Batterien von $Device sollten bald gewechselt werden!"; #Text for changing battery soon
  my $text_changed = "Batterie zuletzt gewechselt: "; #Text for last change
  my $BatteryStatus = "BatterieStatus"; #Name of the Dummy for status
  my $BatteryStatusBot = "BatterieStatusBot"; #Name of the Dummy for status of send messages
  my $BatteryChanged = "BatterieWechsel"; #Name of the Dummy for battery changed information

################################
# Here you choos your message device and how to send
# comment the device you do not want to use
#
# TelegramBot
  my $msg = "set TelegramBot message \@\@User ";
#
# msg-command
# my $msg = "msg \@User title='Battery Check' ";
#
# Pushover 
# my $msg = "set Pushover msg device=User title='Battery Check' ";


  
#  Log3(undef, 1, "my_StoreBatteryStatus      Device: $Device       Event: $Event      Model: $Model");
  
  # ignoring Devices that were just created by autocreate
  if($DeviceNameParts[0] eq "HM" || $DeviceNameParts[0] eq "ZWave" || $DeviceNameParts[0] eq "MAX")
  {
    Log3(undef, 1, "my_StoreBatteryStatus      ignoring Device: $Device");
    return;
  }

  # if it is the first time for that device set it to none (initialize)
  if(ReadingsVal($BatteryStatusBot, $SignalDevice, "undef") eq "undef")
  {
    fhem("setreading $BatteryStatusBot $SignalDevice none");
  }
    
  # actually only devices HM-TC-IT-WM-W-EU and HM-CC-RT-DN have battery level and min-level
  # so calculating the percentage of actual level depending on min-level
  # all others just have battery ok or nok
  # IMPORTANT: first filter those which only send "battery" in EVENT
  #            then calculate for those which send "batteryLevel"!
  #            New devices: ZWave. They deliver battery already in percentage.
  #            New devices: XiaomiFlowerSens. They also deliver batteryLevel but already in percentage.

  #############################################
  #############################################
  # Every device with battery reading
  #############################################
  #############################################
  if($BatteryType[0] eq "battery") 
  {
  
   ##############################################
   # HM Devices with battery
   ##############################################
   if($TYPE eq "CUL_HM" and ReadingsVal($Device, "batteryLevel", "undef") eq "undef")
	{
	 if(ReadingsVal($Device, "battery", "low") eq "ok")
		{
		  # check if battery was low before -> possibly changed
		  if(ReadingsVal($BatteryStatusBot, $SignalDevice, "none") eq "low" || ReadingsVal($BatteryStatus, $Device, 100) < 25)
		  {
			# set date/time for changed battery if it was low before (so probably a change happended)
			fhem("setreading $BatteryChanged $Device $text_changed");
			# set the signal state back to none
			fhem("setreading $BatteryStatusBot $SignalDevice none");
		  }

		  # status is "ok" so we set to 100% (we don't know better)
		  fhem("setreading $BatteryStatus $Device 100");
		}
    else
		{
		  # check if message was already sent
		  if(ReadingsVal($BatteryStatusBot, $SignalDevice, "none") ne "low")
		  {
			# set signal state to low
			fhem("setreading $BatteryStatusBot $SignalDevice low");
			#send message via TelegramBot
			fhem($msg." ".$text_soon);
		  }

		  # status is NOT "ok" ("low") so we set to 0% (we don't know better)
		  fhem("setreading $BatteryStatus $Device 0");
		}
   }
   
   ##############################################
   # ZWave Devices with battery
   ##############################################
   elsif($TYPE eq "ZWave" and ReadingsVal($Device, "batteryLevel", "undef") eq "undef")
   {
	if(ReadingsVal($Device, "battery", "na") eq "low")
		{
		 $ActBatLevel = 0;
		}
	else
		{
		$ActBatLevel = ReadingsNum($Device, "battery", "0");
		}

	if($ActBatLevel > 75)
	   {
		 # set date/time for changed battery if it was low before (so probably a change happended)
		 if(ReadingsVal($BatteryStatusBot, $SignalDevice, "none") eq "low" || ReadingsVal($BatteryStatus, $Device, 100) < 25)
		 {
		   fhem("setreading $BatteryChanged $Device $text_changed");
		 }

		 # set the battery value to 75% - 100%
		 fhem("setreading $BatteryStatus $Device 100");

		 # set the signal state back to none
		 fhem("setreading $BatteryStatusBot $SignalDevice none");
	   }
	elsif($ActBatLevel > 50)
	   {
		# between 50% and 75%
		 fhem("setreading $BatteryStatus $Device 75");

		 # set the signal state back to none
		 if(ReadingsVal($BatteryStatusBot, $SignalDevice, "none") ne "none")
		 {
		   fhem("setreading $BatteryStatusBot $SignalDevice none");
		 }
	   }
	elsif($ActBatLevel > 25)
	   {
		 # between 25% and 50%
		 fhem("setreading $BatteryStatus $Device 50");

		 # set the signal state back to none
		 if(ReadingsVal($BatteryStatusBot, $SignalDevice, "none") ne "none")
		 {
		   fhem("setreading $BatteryStatusBot $SignalDevice none");
		 }
	   }
	elsif($ActBatLevel > 5)
	   {
		 # between 5% and 25%
		 fhem("setreading $BatteryStatus $Device 25");

		 # maybe already send a message! Easy possible with new signal states
	   }
	else
	   {
		  # TODO: test for 0 and then send "change NOW"!
		  # TODO: test for 0 and then send "change NOW"!
		  # TODO: test for 0 and then send "change NOW"!
		  # TODO: test for 0 and then send "change NOW"!
		  # TODO: test for 0 and then send "change NOW"!
		 # totally empty (below 5%)
		 fhem("setreading $BatteryStatus $Device 0");

		 # check if message was already sent
		 if(ReadingsVal($BatteryStatusBot, $SignalDevice, "low") ne "low")
		 {
		   # set signal state to low
		   fhem("setreading $BatteryStatusBot $SignalDevice low");
		   #send message via TelegramBot
		   fhem($msg." ".$text_soon);
		 }
	   }
   }
   
   ##############################################
   # Xiaomi Devices with battery
   ##############################################
   elsif($TYPE =~ "Xiaomi" and ReadingsVal($Device, "batteryLevel", "undef") eq "undef")
   {
    
   }
   
   ##############################################
   # MAX! Devices with battery
   ##############################################
   elsif($TYPE eq "MAX" and ReadingsVal($Device, "batteryLevel", "undef") eq "undef")
   {
	if(ReadingsVal($Device, "battery", "low") eq "ok")
		{
		  # check if battery was low before -> possibly changed
	    if(ReadingsVal($BatteryStatusBot, $SignalDevice, "none") eq "low")
		  {
			# set date/time for changed battery if it was low before (so probably a change happended)
			fhem("setreading $BatteryChanged $Device $text_changed");
			# set the signal state back to none
			fhem("setreading $BatteryStatusBot $SignalDevice none");
		  }

		  # status is "ok" so we set to 100% (we don't know better)
		  fhem("setreading $BatteryStatus $Device 100");
		}
	else
		{
		  # check if message was already sent
		if(ReadingsVal($BatteryStatusBot, $SignalDevice, "none") ne "low")
		  {
			# set signal state to low
			fhem("setreading $BatteryStatusBot $SignalDevice low");
			#send message via TelegramBot
			fhem($msg." ".$text_soon);
		  }

		  # status is NOT "ok" ("low") so we set to 0% (we don't know better)
		  fhem("setreading $BatteryStatus $Device 0");
		}
   }
   
   ##############################################
   # LaCrosse Devices with battery
   ##############################################
   elsif($TYPE eq "LaCrosse" and ReadingsVal($Device, "batteryLevel", "undef") eq "undef")
   {
	if(ReadingsVal($Device, "battery", "low") eq "ok")
		{
		  # check if battery was low before -> possibly changed
	    if(ReadingsVal($BatteryStatusBot, $SignalDevice, "none") eq "low")
		  {
			# set date/time for changed battery if it was low before (so probably a change happended)
			fhem("setreading $BatteryChanged $Device $text_changed");
			# set the signal state back to none
			fhem("setreading $BatteryStatusBot $SignalDevice none");
		  }

		  # status is "ok" so we set to 100% (we don't know better)
		  fhem("setreading $BatteryStatus $Device 100");
		}
	else
		{
		  # check if message was already sent
		if(ReadingsVal($BatteryStatusBot, $SignalDevice, "none") ne "low")
		  {
			# set signal state to low
			fhem("setreading $BatteryStatusBot $SignalDevice low");
			#send message via TelegramBot
			fhem($msg." ".$text_soon);
		  }

		  # status is NOT "ok" ("low") so we set to 0% (we don't know better)
		  fhem("setreading $BatteryStatus $Device 0");
		}
   }
   
   ##############################################
   # All other Devices with battery
   ##############################################
   elsif (ReadingsVal($Device, "batteryLevel", "undef") eq "undef")
   {
    if(ReadingsVal($Device, "battery", "low") eq "ok")
		{
		  # check if battery was low before -> possibly changed
		if(ReadingsVal($BatteryStatusBot, $SignalDevice, "none") eq "low")
		  {
			# set date/time for changed battery if it was low before (so probably a change happended)
			fhem("setreading $BatteryChanged $Device $text_changed");
			# set the signal state back to none
			fhem("setreading $BatteryStatusBot $SignalDevice none");
		  }

		  # status is "ok" so we set to 100% (we don't know better)
		  fhem("setreading $BatteryStatus $Device 100");
		}
	else
		{
		  # check if message was already sent
		if(ReadingsVal($BatteryStatusBot, $SignalDevice, "none") ne "low")
		  {
			# set signal state to low
			fhem("setreading $BatteryStatusBot $SignalDevice low");
			#send message via TelegramBot
			fhem($msg." ".$text_soon);
		  }

		  # status is NOT "ok" ("low") so we set to 0% (we don't know better)
		  fhem("setreading $BatteryStatus $Device 0");
		}
   }
  
  }
  
  #############################################
  #############################################
  # Every device with batteryLevel reading
  #############################################
  #############################################
  elsif($BatteryType[0] eq "batteryLevel")
  {
  
   ##############################################
   # HM Devices with batteryLevel
   ##############################################
   if($TYPE eq "CUL_HM")
   {
	$ActBatLevel = ReadingsVal($Device, "batteryLevel", "0.0");
	$MinBatLevel = ReadingsNum($Device, "R-lowBatLimitRT", "0.0");
	$RemainingVoltageQuater = ($MaxBattery - $MinBatLevel) / 4; # to get 4 quaters for different colours and icons

	if(($ActBatLevel - $MinBatLevel) > (3 * $RemainingVoltageQuater))
		{
		  # check if battery was low before -> possibly changed
		if(ReadingsVal($BatteryStatusBot, $SignalDevice, "none") eq "low" || ReadingsVal($BatteryStatus, $Device, 100) < 25)
		  {
			# set date/time for changed battery if it was low before (so probably a change happended)
			fhem("setreading $BatteryChanged $Device $text_changed");
			# set the signal state back to none
			fhem("setreading $BatteryStatusBot $SignalDevice none");
		  }

		  # set battery value to 100%
		  fhem("setreading $BatteryStatus $Device 100");
		}
	elsif(($ActBatLevel - $MinBatLevel) > (2 * $RemainingVoltageQuater))
		{
		  # between 50% and 75%
		  fhem("setreading $BatteryStatus $Device 75");

		  # set the signal state back to none
		if(ReadingsVal($BatteryStatusBot, $SignalDevice, "none") ne "none")
		  {
			fhem("setreading $BatteryStatusBot $SignalDevice none");
		  }
		}
	elsif(($ActBatLevel - $MinBatLevel) > (1 * $RemainingVoltageQuater))
		{
		  # between 25% and 50%
		  fhem("setreading $BatteryStatus $Device 50");

		  # set the signal state back to none
		if(ReadingsVal($BatteryStatusBot, $SignalDevice, "none") ne "none")
		  {
			fhem("setreading $BatteryStatusBot $SignalDevice none");
		  }
		}
	elsif(($ActBatLevel - $MinBatLevel) > (0 * $RemainingVoltageQuater))
		{
		  # check for critical stuff
		if(ReadingsVal($Device, "motorErr", "ok") eq "lowBat" || ReadingsVal($Device, "motorErr", "ok") eq "ValveErrorPosition")
		  {
			# empty!
			fhem("setreading $BatteryStatus $Device 0");
			# check if message was already sent
			if(ReadingsVal($BatteryStatusBot, $SignalDevice, "low") ne "low")
			{
			  # set signal state to low
			  fhem("setreading $BatteryStatusBot $SignalDevice low");
			  #send message via TelegramBot
			  if(ReadingsVal($Device, "motorErr", "ok") eq "ValveErrorPosition")
			  {
				fhem($msg." ".$text_now);
			  }
			  else
			  {
				fhem($msg." ".$text_soon);
			  }
			}
		  }
		 else
		  {
			# between 0% and 25%
			fhem("setreading $BatteryStatus $Device 25");
		  }
		}
	else
		{
		  # totally empty
		  fhem("setreading $BatteryStatus $Device 0");

		  # check if message was already sent
		  if(ReadingsVal($BatteryStatusBot, $SignalDevice, "low") ne "low")
		  {
			# set signal state to low
			fhem("setreading $BatteryStatusBot $SignalDevice low");
			#send message via TelegramBot
			fhem($msg." ".$text_soon);
		  }
		}
   }
   
   ##############################################
   # Xiaomi Devices with batteryLevel
   ##############################################
   elsif($TYPE =~ "Xiaomi")
   {
    $ActBatLevel = ReadingsNum($Device, "batteryLevel", "0");

	if($ActBatLevel > 75)
	   {
		 # set date/time for changed battery if it was low before (so probably a change happended)
		if(ReadingsVal($BatteryStatusBot, $SignalDevice, "none") eq "low" || ReadingsVal($BatteryStatus, $Device, 100) < 25)
		  {
			fhem("setreading $BatteryChanged $Device $text_changed");
		  }

		  # set the battery value to 75% - 100%
		  fhem("setreading $BatteryStatus $Device 100");

		  # set the signal state back to none
		if(ReadingsVal($BatteryStatusBot, $SignalDevice, "none") ne "none")
		  {
			fhem("setreading $BatteryStatusBot $SignalDevice none");
		  }
		}
	elsif($ActBatLevel > 50)
		{
		  # between 50% and 75%
		  fhem("setreading $BatteryStatus $Device 75");

		  # set the signal state back to none
		if(ReadingsVal($BatteryStatusBot, $SignalDevice, "none") ne "none")
		  {
			fhem("setreading $BatteryStatusBot $SignalDevice none");
		  }
		}
	elsif($ActBatLevel > 25)
		{
		  # between 25% and 50%
		  fhem("setreading $BatteryStatus $Device 50");

		  # set the signal state back to none
		if(ReadingsVal($BatteryStatusBot, $SignalDevice, "none") ne "none")
		  {
			fhem("setreading $BatteryStatusBot $SignalDevice none");
		  }
		}
	elsif($ActBatLevel > 5)
		{
		  # between 5% and 25%
		  fhem("setreading $BatteryStatus $Device 25");

		  # maybe already send a message! Easy possible with new signal states
		}
		else
		{
		  # totally empty (below 5%)
		  fhem("setreading $BatteryStatus $Device 0");

		  # check if message was already sent
		  if(ReadingsVal($BatteryStatusBot, $SignalDevice, "low") ne "low")
		  {
			# set signal state to low
			fhem("setreading $BatteryStatusBot $SignalDevice low");
			#send message via TelegramBot
			fhem($msg." ".$text_soon);
		  }
		}
   }
   
   ##############################################
   # All other Devices with batteryLevel
   ##############################################
   else
   {
    $ActBatLevel = ReadingsNum($Device, "batteryLevel", "0");

	if($ActBatLevel > 75)
	   {
		 # set date/time for changed battery if it was low before (so probably a change happended)
		if(ReadingsVal($BatteryStatusBot, $SignalDevice, "none") eq "low" || ReadingsVal($BatteryStatus, $Device, 100) < 25)
		  {
			fhem("setreading $BatteryChanged $Device $text_changed");
		  }

		  # set the battery value to 75% - 100%
		  fhem("setreading $BatteryStatus $Device 100");

		  # set the signal state back to none
		if(ReadingsVal($BatteryStatusBot, $SignalDevice, "none") ne "none")
		  {
			fhem("setreading $BatteryStatusBot $SignalDevice none");
		  }
		}
	elsif($ActBatLevel > 50)
		{
		  # between 50% and 75%
		  fhem("setreading $BatteryStatus $Device 75");

		  # set the signal state back to none
		if(ReadingsVal($BatteryStatusBot, $SignalDevice, "none") ne "none")
		  {
			fhem("setreading $BatteryStatusBot $SignalDevice none");
		  }
		}
	elsif($ActBatLevel > 25)
		{
		  # between 25% and 50%
		  fhem("setreading $BatteryStatus $Device 50");

		  # set the signal state back to none
		if(ReadingsVal($BatteryStatusBot, $SignalDevice, "none") ne "none")
		  {
			fhem("setreading $BatteryStatusBot $SignalDevice none");
		  }
		}
	elsif($ActBatLevel > 5)
		{
		  # between 5% and 25%
		  fhem("setreading $BatteryStatus $Device 25");

		  # maybe already send a message! Easy possible with new signal states
		}
		else
		{
		  # totally empty (below 5%)
		  fhem("setreading $BatteryStatus $Device 0");

		  # check if message was already sent
		  if(ReadingsVal($BatteryStatusBot, $SignalDevice, "low") ne "low")
		  {
			# set signal state to low
			fhem("setreading $BatteryStatusBot $SignalDevice low");
			#send message via TelegramBot
			fhem($msg." ".$text_soon);
		  }
		}
   }
  }

}

##################################################
# Helper for readingsGroup BatteryStatus:
# sets the icon and icon color depending on "calculated" percentage value
sub SetBatterieIcon($$)
{
  my ($Device, $Value)  = @_;
  my $Icon = "measure_battery_" . "$Value"; # here the matching icon is "set"
  my $ActionDetectorDevice = "status_" . $Device;
  my $Name = ""; # name for signal state
  my $State = ReadingsVal("ActionDetector", $ActionDetectorDevice, "alive");

#  Log3(undef, 1, "my_SetBatteryIcon      Device: $Device       Value: $Value");

  if($State ne "alive")
  {
    $Icon = "message_attention\@red";
  }
  else
  {
    if($Value > 75)
    {
      $Icon = $Icon . "\@green"; # between 75% and 100%
    }
    elsif($Value > 25)
    {
      $Icon = $Icon . "\@orange"; # between 25% and 75%
    }
    else
    {
      $Icon = $Icon . "\@red"; # below 25%
    }
  }

  return $Icon;
}

#####################################################
# Start script once and delet after

sub BatteryStart()
{
 #Define Dummys for script
 my $BatteryStatus = "BatterieStatus"; #Name of the Dummy for status
 my $BatteryStatusBot = "BatterieStatusBot"; #Name of the Dummy for status of send messages
 my $BatteryChanged = "BatterieWechsel"; #Name of the Dummy for battery changed information
 my $ReadingsGroup = "rgBatteryStatus"; #Name of the ReadingsGroup
 my $Room = "Z_System->BatteryCheck"; #room for the dummys
 my $Notify = "NO.BatterieNotify"; #Name of the Notify for sending battery information
 
 fhem("setdefaultattr room $Room; define $BatteryStatus dummy; define $BatteryStatusBot dummy; define $BatteryChanged dummy; 
      define $ReadingsGroup readingsGroup NAME=BatterieStatus:.*; attr $ReadingsGroup valueIcon {SetBatterieIcon(\$READING, \$VALUE)};
      attr $ReadingsGroup mapping \$READING; setdefaultattr;");
 
 
 #Set Readings for device with reading battery
 my @bat_b = devspec2array("battery=.*");
 for(my $x=0;$x<@bat_b;$x++)
 {
 	my $stat_b = ReadingsVal($bat_b[$x],"battery","undef");
 	if($stat_b ne "undef") 
	{
	 BatteryStatusFunction($bat_b[$x],"battery: $stat_b");
	}
 }
 
 #Set Readings for device with reading batteryLevel
 my @bat_l = devspec2array("batteryLevel=.*");
 for(my $x=0;$x<@bat_l;$x++)
 {
	my $stat_l = ReadingsVal($bat_l[$x],"batteryLevel","undef");
	if($stat_l ne "undef") 
	{
	 BatteryStatusFunction($bat_l[$x],"batteryLevel: $stat_l");
	}
 }
 
 fhem("define $Notify notify .*:battery.* {BatteryStatusFunction(\$NAME, \$EVENT)}; attr $Notify room $Room;")
}
