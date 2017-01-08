dofile("urlcode.lua")
dofile("table_show.lua")
JSON = (loadfile "JSON.lua")()

local url_count = 0
local tries = 0
local item_type = os.getenv('item_type')
local item_value = os.getenv('item_value')
local random_number = tonumber(os.getenv('random_number'))

local downloaded = {}
local addedtolist = {}

local images = {}

local abortgrab = false

for ignore in io.open("ignore-list", "r"):lines() do
  downloaded[ignore] = true
end

for image in string.gmatch(item_value, "([^,]+)") do
  images[string.match(image, "/([0-9]+)")] = true
end

load_json_file = function(file)
  if file then
    return JSON:decode(file)
  else
    return nil
  end
end

read_file = function(file)
  if file then
    local f = assert(io.open(file))
    local data = f:read("*all")
    f:close()
    return data
  else
    return ""
  end
end

allowed = function(url)
  if string.match(url, "^https?://api%.flickr%.com/services/") then
    return true
  end
  if string.match(url, "^https://www.flickr.com/photos/[^/]+/[0-9]+$") then
    local newimage = string.match(url, "^https://www.flickr.com/photos/([^/]+/[0-9]+)$")
    for image in string.gmatch(item_value, "([^,]+)") do
      if newimage == image then
        return false
      end
    end
  end
  for i in string.gmatch(url, "([0-9]+)") do
    if images[i] == true and (string.match(url, "^https?://[^/]*flickr%.com") or string.match(url, "^https?://[^/]*yimg%.com")) and not (string.match(url, "\\") or string.match(url, "{") or string.match(url, "}")) then
      return true
    end
  end
  return false
end

wget.callbacks.download_child_p = function(urlpos, parent, depth, start_url_parsed, iri, verdict, reason)
  local url = urlpos["url"]["url"]
  local html = urlpos["link_expect_html"]

  if string.match(url, "^https?://y3%.analytics%.yahoo%.com") then
    return false
  end

  if (downloaded[url] ~= true and addedtolist[url] ~= true) and (allowed(url) or (html == 0 and not (string.match(url, "https?://[^/]*staticflickr%.com/[0-9]*/?[0-9]+/buddyicons") or string.match(url, "https?://[^/]*staticflickr%.com/[0-9]+/coverphoto/")))) and not string.match(url, "https?://[^/]*staticflickr%.com/[0-9]+/?[0-9]+/[0-9]+_[a-f0-9]+") then
    addedtolist[url] = true
    return true
  else
    return false
  end
end

wget.callbacks.get_urls = function(file, url, is_css, iri)
  local urls = {}
  local html = nil

  downloaded[url] = true
  
  local function check(urla)
    local url = string.match(urla, "^([^#]+)")
    if (downloaded[url] ~= true and addedtolist[url] ~= true) and allowed(url) then
      if string.match(url, "&amp;") then
        table.insert(urls, { url=string.gsub(url, "&amp;", "&") })
        addedtolist[url] = true
        addedtolist[string.gsub(url, "&amp;", "&")] = true
      else
        table.insert(urls, { url=url })
        addedtolist[url] = true
      end
    end
  end

  local function checknewurl(newurl)
    if string.match(newurl, "^https?:////") then
      check(string.gsub(newurl, ":////", "://"))
    elseif string.match(newurl, "^https?://") then
      check(newurl)
    elseif string.match(newurl, "^https?:\\/\\/") then
      check(string.gsub(newurl, "\\", ""))
    elseif string.match(newurl, "^\\/\\/") then
      check(string.match(url, "^(https?:)")..string.gsub(newurl, "\\", ""))
    elseif string.match(newurl, "^//") then
      check(string.match(url, "^(https?:)")..newurl)
    elseif string.match(newurl, "^\\/") then
      check(string.match(url, "^(https?://[^/]+)")..string.gsub(newurl, "\\", ""))
    elseif string.match(newurl, "^/") then
      check(string.match(url, "^(https?://[^/]+)")..newurl)
    end
  end

  local function checknewshorturl(newurl)
    if string.match(newurl, "^%?") then
      check(string.match(url, "^(https?://[^%?]+)")..newurl)
    elseif not (string.match(newurl, "^https?:\\?/\\?//?/?") or string.match(newurl, "^[/\\]") or string.match(newurl, "^[jJ]ava[sS]cript:") or string.match(newurl, "^[mM]ail[tT]o:") or string.match(newurl, "^%${") or string.match(newurl, "^magnet:")) then
      check(string.match(url, "^(https?://.+/)")..newurl)
    end
  end

-- Code below will be done from inside the Wayback Machine.

--  if string.match(url, "^https?://c[1-8]*%.staticflickr%.com/.+") then
--    local pre = string.match(url, "^(https?://c)[1-8]*%.staticflickr%.com/.+$")
--    local image = string.match(url, "^https?://c[1-8]*(%.staticflickr%.com/.+)$")
--    check(pre .. image)
--    for i=1,8 do
--      check(pre .. tostring(i) .. image)
--    end
--  end

--  if string.match(url, "^https?://farm[1-9]+%.staticflickr%.com/.+") then
--    local pre = string.match(url, "^(https?://farm)[1-9]+%.staticflickr%.com/.+$")
--    local image = string.match(url, "^https?://farm[1-9]+(%.staticflickr%.com/.+)$")
--    for i=1,9 do
--      check(pre .. tostring(i) .. image)
--    end
--  end
  
  if allowed(url) and not (string.match(url, "^https?://[^/]*staticflickr%.com/") or string.match(url, "^https?://[^/]*yimg%.com")) then
    html = read_file(file)

    if string.match(html, "hermes%-[0-9]%.[0-9]%.[0-9]+") and random_number == 250 then
      local hermesversion = string.match(html, "(hermes%-[0-9]%.[0-9]%.[0-9]+)")
      for hermesurl in io.open("hermes-list", "r"):lines() do
        local newurl = string.gsub(hermesurl, "{{VERSION}}", hermesversion)
        if downloaded[newurl] ~= true and addedtolist[newurl] ~= true then
          table.insert(urls, { url=newurl })
          addedtolist[newurl] = true
        end
      end
      random_number = 10000
    end

    if string.match(url, "^https://www.flickr.com/photos/[^/]+/[0-9]+/") and
       string.match(html, 'root%.YUI_config%.flickr%.api%.site_key%s+=%s+"[0-9a-f]+"') and
       string.match(html, 'root%.YUI_config%.flickr%.request%.id%s+=%s+"[0-9a-f]+"') and
       string.match(html, '"nsid":%s*"[^"]+"') and 
       string.match(html, '"secret":%s*"[0-9a-f]+"') then
      local photo_id = string.match(url, "https://www.flickr.com/photos/[^/]+/([0-9]+)/")
      local user = string.gsub(string.match(html, '"nsid":%s*"([^"]+)"'), '@', '%%40')
      local api_key = string.match(html, 'root%.YUI_config%.flickr%.api%.site_key%s+=%s+"([0-9a-f]+)"')
      local req_id = string.match(html, 'root%.YUI_config%.flickr%.request%.id%s+=%s+"([0-9a-f]+)"')
      local secret = string.match(html, '"secret":%s*"([0-9a-f]+)"')
      check("https://api.flickr.com/services/rest?photo_id=" .. photo_id .. "&offset=0&limit=20&sort=date-posted-desc&extras=icon_urls&expand_bbml=1&use_text_for_links=1&secure_image_embeds=1&bbml_need_all_photo_sizes=1&primary_photo_longest_dimension=405&viewerNSID=&method=flickr.photos.comments.getList&csrf=&api_key=" .. api_key .. "&format=json&hermes=1&hermesClient=1&reqId=" .. req_id .. "&nojsoncallback=1")
      --check("https://api.flickr.com/services/rest?photo_id=" .. photo_id .. "&offset=0&limit=1&sort=date-posted-desc&extras=icon_urls&expand_bbml=1&use_text_for_links=1&secure_image_embeds=1&bbml_need_all_photo_sizes=1&primary_photo_longest_dimension=405&viewerNSID=&method=flickr.photos.comments.getList&csrf=&api_key=" .. api_key .. "&format=json&hermes=1&hermesClient=1&reqId=" .. req_id .. "&nojsoncallback=1")
      check("https://api.flickr.com/services/rest?photo_id=" .. photo_id .. "&extras=autotags&lang=en-US&viewerNSID=&method=flickr.tags.getListPhoto&csrf=&api_key=" .. api_key .. "&format=json&hermes=1&hermesClient=1&reqId=" .. req_id .. "&nojsoncallback=1")
      check("https://api.flickr.com/services/rest?photo_id=" .. photo_id .. "&extras=can_addmeta%2Ccan_comment%2Ccan_download%2Ccan_share%2Ccontact%2Ccount_comments%2Ccount_faves%2Ccount_views%2Cdate_taken%2Cdate_upload%2Cdescription%2Cicon_urls_deep%2Cisfavorite%2Cispro%2Clicense%2Cmedia%2Cneeds_interstitial%2Cowner_name%2Cowner_datecreate%2Cpath_alias%2Crealname%2Crotation%2Csafety_level%2Csecret_k%2Csecret_h%2Curl_c%2Curl_f%2Curl_h%2Curl_k%2Curl_l%2Curl_m%2Curl_n%2Curl_o%2Curl_q%2Curl_s%2Curl_sq%2Curl_t%2Curl_z%2Cvisibility%2Cvisibility_source%2Co_dims%2Cis_marketplace_printable%2Cis_marketplace_licensable%2Cpubliceditability&per_page=50&page=1&hermes=1&sort=date_asc&viewerNSID=&method=flickr.photos.getFavorites&csrf=&api_key=" .. api_key .. "&format=json&hermesClient=1&reqId=" .. req_id .. "&nojsoncallback=1")
      check("https://api.flickr.com/services/rest?photo_id=" .. photo_id .. "&extras=camera&viewerNSID=&method=flickr.photos.getExif&csrf=&api_key=" .. api_key .. "&format=json&hermes=1&hermesClient=1&reqId=" .. req_id .. "&nojsoncallback=1")
      check("https://api.flickr.com/services/rest?photo_id=" .. photo_id .. "&extras=can_addmeta%2Ccan_comment%2Ccan_download%2Ccan_share%2Ccontact%2Ccount_comments%2Ccount_faves%2Ccount_views%2Cdate_taken%2Cdate_upload%2Cdescription%2Cicon_urls_deep%2Cisfavorite%2Cispro%2Clicense%2Cmedia%2Cneeds_interstitial%2Cowner_name%2Cowner_datecreate%2Cpath_alias%2Crealname%2Crotation%2Csafety_level%2Csecret_k%2Csecret_h%2Curl_c%2Curl_f%2Curl_h%2Curl_k%2Curl_l%2Curl_m%2Curl_n%2Curl_o%2Curl_q%2Curl_s%2Curl_sq%2Curl_t%2Curl_z%2Cvisibility%2Cvisibility_source%2Co_dims%2Cis_marketplace_printable%2Cis_marketplace_licensable%2Cpubliceditability%2Cdatecreate%2Cdate_activity%2Ceighteenplus%2Cinvitation_only%2Cneeds_interstitial%2Cnon_members_privacy%2Cpool_pending_count%2Cprivacy%2Cmember_pending_count%2Cicon_urls%2Cdate_activity_detail%2Cowner_name%2Cpath_alias%2Crealname%2Csizes%2Curl_m%2Curl_n%2Curl_q%2Curl_s%2Curl_sq%2Curl_t%2Curl_z%2Curl_c%2Curl_h%2Curl_k%2Curl_l%2Curl_z%2Cneeds_interstitial&primary_photo_extras=url_sq%2C%20url_t%2C%20url_s%2C%20url_m%2C%20needs_interstitial&get_all_galleries=1&no_faves_context=1&per_type_limit=6&get_totals=1&sort=date-desc&viewerNSID=&method=flickr.photos.getAllContexts&csrf=&api_key=" .. api_key .. "&format=json&hermes=1&hermesClient=1&reqId=" .. req_id .. "&nojsoncallback=1")
      check("https://api.flickr.com/services/rest?photo_id=" .. photo_id .. "&extras=icon_urls%2C%20paid_products&viewerNSID=&method=flickr.photos.people.getList&csrf=&api_key=" .. api_key .. "&format=json&hermes=1&hermesClient=1&reqId=" .. req_id .. "&nojsoncallback=1")
      check("https://api.flickr.com/services/rest?photo_id=" .. photo_id .. "&num_prev=18&num_next=18&extras=can_addmeta%2Ccan_comment%2Ccan_download%2Ccan_share%2Ccontact%2Ccount_comments%2Ccount_faves%2Ccount_views%2Cdate_taken%2Cdate_upload%2Cdescription%2Cicon_urls_deep%2Cisfavorite%2Cispro%2Clicense%2Cmedia%2Cneeds_interstitial%2Cowner_name%2Cowner_datecreate%2Cpath_alias%2Crealname%2Crotation%2Csafety_level%2Csecret_k%2Csecret_h%2Curl_c%2Curl_f%2Curl_h%2Curl_k%2Curl_l%2Curl_m%2Curl_n%2Curl_o%2Curl_q%2Curl_s%2Curl_sq%2Curl_t%2Curl_z%2Cvisibility%2Cvisibility_source%2Co_dims%2Cis_marketplace_printable%2Cis_marketplace_licensable%2Cpubliceditability&viewerNSID=&method=flickr.photos.getContext&csrf=&api_key=" .. api_key .. "&format=json&hermes=1&hermesClient=1&reqId=" .. req_id .. "&nojsoncallback=1")
      check("https://api.flickr.com/services/rest?photo_id=" .. photo_id .. "&num_prev=15&num_next=15&extras=can_addmeta%2Ccan_comment%2Ccan_download%2Ccan_share%2Ccontact%2Ccount_comments%2Ccount_faves%2Ccount_views%2Cdate_taken%2Cdate_upload%2Cdescription%2Cicon_urls_deep%2Cisfavorite%2Cispro%2Clicense%2Cmedia%2Cneeds_interstitial%2Cowner_name%2Cowner_datecreate%2Cpath_alias%2Crealname%2Crotation%2Csafety_level%2Csecret_k%2Csecret_h%2Curl_c%2Curl_f%2Curl_h%2Curl_k%2Curl_l%2Curl_m%2Curl_n%2Curl_o%2Curl_q%2Curl_s%2Curl_sq%2Curl_t%2Curl_z%2Cvisibility%2Cvisibility_source%2Co_dims%2Cis_marketplace_printable%2Cis_marketplace_licensable%2Cpubliceditability&viewerNSID=&method=flickr.photos.getContext&csrf=&api_key=" .. api_key .. "&format=json&hermes=1&hermesClient=1&reqId=" .. req_id .. "&nojsoncallback=1")
      check("https://www.flickr.com/beacon_rb_jserror.gne?reqId=" .. req_id .. "&initialView=photo-page-scrappy-view&error=time_to_load_photo_only&url=https%3A%2F%2Fwww.flickr.com%2Fphotos%2F" .. user .. "%2F" .. photo_id .. "%2F&duration=57")
      check("https://api.flickr.com/services/rest?extras=can_addmeta%2Ccan_comment%2Ccan_download%2Ccan_share%2Ccontact%2Ccount_comments%2Ccount_faves%2Ccount_views%2Cdate_taken%2Cdate_upload%2Cdescription%2Cicon_urls_deep%2Cisfavorite%2Cispro%2Clicense%2Cmedia%2Cneeds_interstitial%2Cowner_name%2Cowner_datecreate%2Cpath_alias%2Crealname%2Crotation%2Csafety_level%2Csecret_k%2Csecret_h%2Curl_c%2Curl_f%2Curl_h%2Curl_k%2Curl_l%2Curl_m%2Curl_n%2Curl_o%2Curl_q%2Curl_s%2Curl_sq%2Curl_t%2Curl_z%2Cvisibility%2Cvisibility_source%2Co_dims%2Cis_marketplace_printable%2Cis_marketplace_licensable%2Cpubliceditability&context_id=global&context_type=global&viewerNSID=&method=flickr.autosuggest.getContextResults&csrf=&api_key=" .. api_key .. "&format=json&hermes=1&hermesClient=1&reqId=" .. req_id .. "&nojsoncallback=1")
      --check("https://api.flickr.com/services/rest?photo_id=" .. photo_id .. "&offset=0&limit=13&sort=date-posted-desc&extras=icon_urls&expand_bbml=1&use_text_for_links=1&secure_image_embeds=1&bbml_need_all_photo_sizes=1&primary_photo_longest_dimension=405&viewerNSID=&method=flickr.photos.comments.getList&csrf=&api_key=" .. api_key .. "&format=json&hermes=1&hermesClient=1&reqId=" .. req_id .. "&nojsoncallback=1")
      check("https://api.flickr.com/services/rest?per_page=20&page=1&extras=can_addmeta%2Ccan_comment%2Ccan_download%2Ccan_share%2Ccontact%2Ccount_comments%2Ccount_faves%2Ccount_views%2Cdate_taken%2Cdate_upload%2Cdescription%2Cicon_urls_deep%2Cisfavorite%2Cispro%2Clicense%2Cmedia%2Cneeds_interstitial%2Cowner_name%2Cowner_datecreate%2Cpath_alias%2Crealname%2Crotation%2Csafety_level%2Csecret_k%2Csecret_h%2Curl_c%2Curl_f%2Curl_h%2Curl_k%2Curl_l%2Curl_m%2Curl_n%2Curl_o%2Curl_q%2Curl_s%2Curl_sq%2Curl_t%2Curl_z%2Cvisibility%2Cvisibility_source%2Co_dims%2Cis_marketplace_printable%2Cis_marketplace_licensable%2Cpubliceditability&get_user_info=1&jump_to=&user_id=" .. user .. "&viewerNSID=&method=flickr.people.getPhotos&csrf=&api_key=" .. api_key .. "&format=json&hermes=1&hermesClient=1&reqId=" .. req_id .. "&nojsoncallback=1")
      --check("https://api.flickr.com/services/rest?photo_id=" .. photo_id .. "&offset=0&limit=7&sort=date-posted-desc&extras=icon_urls&expand_bbml=1&use_text_for_links=1&secure_image_embeds=1&bbml_need_all_photo_sizes=1&primary_photo_longest_dimension=405&viewerNSID=&method=flickr.photos.comments.getList&csrf=&api_key=" .. api_key .. "&format=json&hermes=1&hermesClient=1&reqId=" .. req_id .. "&nojsoncallback=1")
      check("https://api.flickr.com/services/rest?photo_id=" .. photo_id .. "&secret=" .. secret .. "&viewerNSID=&method=flickr.video.getStreamInfo&csrf=&api_key=" .. api_key .. "&format=json&hermes=1&hermesClient=1&reqId=" .. req_id .. "&nojsoncallback=1")
    end

    --if string.match(url, "https?://api%.flickr%.com/services/rest") and string.match(url, "page=[0-9]+") and string.match(html, '"pages":%s*[0-9]+') then
    --  i_ = string.match(html, '"pages":([0-9]+)')
    --  for i=1,tonumber(i_) do
    --    check(string.gsub(url, "&page=[0-9]+", "&page=" .. tostring(i)))
    --  end
    --end

    if string.match(url, "https?://api%.flickr%.com/services/rest%?photo_id=[0-9]+&offset=[0-9]+&limit=[0-9]+") then
      local json_ = load_json_file(html)
      local limit = tonumber(string.match(url, "limit=([0-9]+)"))
      local offset = tonumber(string.match(url, "offset=([0-9]+)"))
      local comments = json_["comments"]["comment"]
      local numcomments = 0
      if comments then
        for _ in pairs(comments) do
          numcomments = numcomments + 1
        end
      end
      if numcomments == limit and (limit == 200 or (limit == 20 and offset == 0)) then
        print(string.gsub(string.gsub(url, "offset=[0-9]+", "offset=" .. tostring(offset + limit)), "limit=[0-9]+", "limit=200"))
        check(string.gsub(string.gsub(url, "offset=[0-9]+", "offset=" .. tostring(offset + limit)), "limit=[0-9]+", "limit=200"))
      else
        check(string.gsub(url, "limit=[0-9]+", "limit=" .. tostring(numcomments)))
      end
    end

    for newurl in string.gmatch(html, '([^"]+)') do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, "([^']+)") do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, ">%s*([^<%s]+)") do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, "href='([^']+)'") do
      checknewshorturl(newurl)
    end
    for newurl in string.gmatch(html, 'href="([^"]+)"') do
      checknewshorturl(newurl)
    end
  end

  return urls
end
  

wget.callbacks.httploop_result = function(url, err, http_stat)
  -- NEW for 2014: Slightly more verbose messages because people keep
  -- complaining that it's not moving or not working
  status_code = http_stat["statcode"]
  
  url_count = url_count + 1
  io.stdout:write(url_count .. "=" .. status_code .. " " .. url["url"] .. ".  \n")
  io.stdout:flush()

  if (status_code >= 200 and status_code <= 399) then
    downloaded[url["url"]] = true
  end

  if abortgrab == true then
    io.stdout:write("Script on flickr have been updated. ABORTING...\n")
    return wget.actions.ABORT
  end
  
  if status_code >= 500 or
    (status_code >= 400 and status_code ~= 404) or
    status_code == 0 then
    io.stdout:write("Server returned "..http_stat.statcode.." ("..err.."). Sleeping.\n")
    io.stdout:flush()
    os.execute("sleep 1")
    tries = tries + 1
    if tries >= 5 then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      tries = 0
      if allowed(url["url"]) then
        return wget.actions.ABORT
      else
        return wget.actions.EXIT
      end
    else
      return wget.actions.CONTINUE
    end
  end

  tries = 0

  local sleep_time = 0

  if sleep_time > 0.001 then
    os.execute("sleep " .. sleep_time)
  end

  return wget.actions.NOTHING
end

wget.callbacks.before_exit = function(exit_status, exit_status_string)
  if abortgrab == true then
    return wget.exits.IO_FAIL
  end
  return exit_status
end