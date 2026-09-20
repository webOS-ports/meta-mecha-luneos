# @@@LICENSE
#
#      Copyright (c) 2010-2019 LG Electronics, Inc.
#      Copyright (c) 2026 Herman van Hazendonk
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# LICENSE@@@

# configuration file for the Mecha Comet (i.MX8M Plus).

set(DEVICEINFO_PRODUCT_NAME			"Comet")

# Battery: ti,bq27441 fuel gauge on I2C, with a full simple-battery profile in
# the device tree (1430 mAh / 5.29 Wh). The open-webos battery module reads it
# through /sys/class/power_supply, so this is the plain sysfs backend, not a
# hybris one.
set(NYXMOD_OW_BATTERY				TRUE)
set(NYXMOD_OW_CHARGER				TRUE)

# Home, VOL+ and VOL- are gpio-keys in the device tree; so is the module bay's
# slide detect, which reports KEY_F24 and is not a user-facing key.
set(NYXMOD_OW_KEYS					TRUE)

set(NYXMOD_OW_TOUCHPANEL			FALSE)
set(NYXMOD_OW_TOUCHPANEL_MTDEV		TRUE)

set(NYXMOD_OW_LED					TRUE)

# pwm-vibrator on pwm1, gated by the PCA9535 expander.
set(NYXMOD_OW_HAPTICS				TRUE)

# Focaltech FT3519 on i2c2 (0x30a30000 on the i.MX8M Plus). Pinned by path
# rather than by event number for the reason the nyx.conf generator's header
# gives: the numbering moves when probe order changes, the path does not.
add_definitions(-DTOUCHPANEL_DEVICE=\"/dev/input/by-path/platform-30a30000.i2c-event\")
