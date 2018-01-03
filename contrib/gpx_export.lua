--[[
    This file is part of darktable,
    copyright (c) 2017 Jannis_V

    darktable is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
    darktable is distributed in the hope that it will be useful,
     but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
    You should have received a copy of the GNU General Public License
    along with darktable.  If not, see <http://www.gnu.org/licenses/>.
]]

--[[
Simple darktable GPX generator script

This script generates a GPX track from all images having GPS latitude
and longitude information
]]

local dt = require "darktable"
local df = require "lib/dtutils.file"
local dl = require "lib/dtutils"
local gettext = dt.gettext

dt.configuration.check_version(...,{3,0,0},{4,0,0},{5,0,0})

-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("gpx_export",dt.configuration.config_dir.."/lua/locale/")

local function _(msgid)
  return gettext.dgettext("gpx_export", msgid)
end

local path_entry = dt.new_widget("entry")
{
  text = dt.preferences.read("gpx_exporter", "gpxExportPath", "string"),
  editable=true,
  reset_callback = function(self)
    self.text = "~/darktable.gpx"
    dt.preferences.write("gpx_exporter", "gpxExportPath", "string", self.text)
  end,
  tooltip = _("gpx file path"),
}

local function stop_job(job)
  job.valid = false
end

local function create_gpx_file()
  dt.preferences.write("gpx_exporter", "gpxExportPath", "string", path_entry.text)

  path = path_entry.text:gsub("^~", os.getenv("HOME")) -- Expand ~ to home
  path = path:gsub("//", "/")

  dt.print(_("exporting gpx file..."))

  job = dt.gui.create_job(_("gpx export"), true, stop_job)

  local gpx_file = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\" ?>\n"
  gpx_file = gpx_file.."<gpx xmlns=\"http://www.topografix.com/GPX/1/1\" creator=\"Darktable GPX Exporter\"\n version=\"1.1\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"\n xsi:schemaLocation=\"http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd\">\n"
  gpx_file = gpx_file.."\t<trk>\n"
  gpx_file = gpx_file.."\t\t<trkseg>\n";

  local sel_images = dt.gui.action_images
  for key,image in dl.spairs(sel_images, function(t, a, b) return t[b].exif_datetime_taken > t[a].exif_datetime_taken end) do

    if(job.valid) then
      job.percent = (key - 1) / #sel_images

      if ((image.longitude and image.latitude) and
        (image.longitude ~= 0 and image.latitude ~= 90) -- Just in case
      ) then

        if(image.exif_datetime_taken == "") then
          dt.print(image.path.."/"..image.filename.._(" does not have date information and won't be processed"))
          print(image.path.."/"..image.filename.._(" does not have date information and won't be processed")) -- Also print to terminal
        else
          date_format = "(%d+):(%d+):(%d+) (%d+):(%d+):(%d+)"
          my_year, my_month, my_day, my_hour, my_min, my_sec = image.exif_datetime_taken:match(date_format)

          local my_timestamp = os.time({year=my_year, month=my_month, day=my_day, hour=my_hour, min=my_min, sec=my_sec})

          gpx_file = gpx_file.."\t\t\t<trkpt lat=\""..string.gsub(tostring(image.latitude), ",", ".").."\" lon=\""..string.gsub(tostring(image.longitude), ",", ".").."\">\n"
          gpx_file = gpx_file.."\t\t\t\t<time>"..os.date("!%Y-%m-%dT%H:%M:%SZ",my_timestamp).."</time>\n"
          gpx_file = gpx_file.."\t\t\t</trkpt>\n"
        end
      end
      else
        break
    end
  end

  job.valid = false

  gpx_file = gpx_file.."\t\t</trkseg>\n";
  gpx_file = gpx_file.."\t</trk>\n";
  gpx_file = gpx_file.."</gpx>\n";

  local file = io.open(path, "w")
  if (file == nil) then
    dt.print(_("invalid path: ")..path)
  else
    file:write(gpx_file)
    file:close()
    dt.print(_("gpx file created: ")..path)
  end
end

dt.register_lib(
  "gpx_exporter",
  "gpx export",
  true, -- expandable
  true, -- resetable
  {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 100}},   -- containers
  dt.new_widget("box")
  {
    orientation = "vertical",
    dt.new_widget("button")
    {
      label = _("export"),
      tooltip = _("export gpx file"),
      clicked_callback = create_gpx_file
    },
    dt.new_widget("box")
    {
      orientation = "horizontal",
      dt.new_widget("label")
      {
        label = _("file:"),
      },
      path_entry
    },
  },
  nil,-- view_enter
  nil -- view_leave
)
