#!/usr/bin/env bash


if [ ! -d "listing" ]; then
    mkdir listing
fi

_lt_Config=".appdblink"
_linkingTicket="$(cat .appdblink)";
_appdbAPI="https://api.dbservices.to/v1.2/";
_devices_list="devicedata.json"
_commandLog="mynewlog.json"


if [ -f "$_commandLog" ]; then
    rm "mynewlog.json"
    touch "mynewlog.json"
fi

appdb_news()              { curl -Ss -X POST --globoff -F "action=get_news" -F "limit=1" "$_appdbAPI" | jq -r '.data[] | .title'; }
appdb_link()              { curl -Ss -X POST --globoff -F "action=link" -F "type=control" -F "link_code=$1" "$_appdbAPI" | jq -r '.data[]'; }
appdb_devices()           { curl -Ss -X POST --globoff -F "action=get_all_devices" -b "lt="$_linkingTicket"" "$_appdbAPI" > "$_devices_list";}
appdb_device_status()     { curl -Ss -X POST --globoff -F "action=get_status" -b "lt="$_linkingTicket"" "$_appdbAPI" | jq -r >> mynewlog.json;}
__top_ios_day()           { curl -Ss -X POST --globoff -F "action=search" -F "type=ios" -F "order=clicks_day" -F "page="$1"" -F "perpage=5" -b "lt="$_linkingTicket"" "$_appdbAPI" | jq -r . > listing/ios_page1.json;}
__top_cydia_day()         { curl -Ss -X POST --globoff -F "action=search" -F "type=cydia" -F "order=clicks_day" -F "page="$1"" -F "perpage=5" -b "lt="$_linkingTicket"" "$_appdbAPI" | jq -r . > listing/cydia_page1.json;}
__getLinks()              { curl -Ss -X POST --globoff -F "action=get_links" -F "type="$1"" -F "trackids="$2""  -b "lt="$_linkingTicket"" "$_appdbAPI" |jq -r > listing/links.json;}
__getRevokeID()           { curl -Ss -X POST --globoff -F "action=get_protection_validation_id" -b "lt="$_linkingTicket"" "$_appdbAPI" | jq -r .data;}
__defaultInstall()        { curl -Ss -X POST --globoff -F "action=install" -F "id="$1"" -F "type="$2"" -F "validation_id="$3"" -b "lt="$_linkingTicket"" "$_appdbAPI";}
__customInstall()         { curl -Ss -X POST --globoff -F "action=install" -F "id="$1"" -F "type="$2"" -F "validation_id="$3"" -F "is_alongside="$4"" -F "display_name="$5"" -b "lt="$_linkingTicket"" "$_appdbAPI";}
__latest_ios()            { curl -Ss -X POST --globoff -F "action=search" -F "type=ios" -F "page="$1"" -F "perpage=5" -b "lt="$_linkingTicket"" "$_appdbAPI" | jq -r . > listing/ios_page1.json;}
__latest_cydia()          { curl -Ss -X POST --globoff -F "action=search" -F "type=cydia" -F "page="$1"" -F "perpage=5" -b "lt="$_linkingTicket"" "$_appdbAPI" | jq -r . > listing/cydia_page1.json;}
__search_ios()            { curl -Ss -X POST --globoff -F "action=search" -F "type=ios" -F "page="$1"" -F "perpage=5" -F "q="$2"" -b "lt="$_linkingTicket"" "$_appdbAPI" | jq -r . > listing/ios_page1.json;}
__search_cydia()          { curl -Ss -X POST --globoff -F "action=search" -F "type=cydia" -F "page="$1"" -F "perpage=5" -F "q="$2"" -b "lt="$_linkingTicket"" "$_appdbAPI" | jq -r . > listing/cydia_page1.json;}


function __fetchLatestCommands(){
    if [ -f "$_commandLog" ]; then
        rm "$_commandLog";
        touch "$_commandLog";
    fi
    while [ true ]; do
        appdb_device_status;
    # sleep 1
                _getStatusText=`cat mynewlog.json | jq -r '.data[0] | .params' | jq -r .'sign | .status_text' | sed -e 's/\<br\/\>//' -e 's/null//g'`
                            if [ -n "$_getStatusText" ]; then
                                echo "$_getStatusText" | tail -2;
                            fi
                _getStatusPurpose=`cat mynewlog.json | jq -r '.data[0] | .params' | jq -r .'purpose'`
            if [[ "$_getStatusPurpose" = *signed* ]]; then
                echo "$_getStatusPurpose" | tail -1;
                exit;
            fi
            if [[ "$_getStatusText" = *terminated* ]] || [[ "$_getStatusText" = *Broken* ]]; then
                exit;
            fi

    done
}

function menuPicker() {
    echo "$1"; shift
    echo `tput sitm``tput dim`-" AppDB CLI" `tput sgr0`
    echo `tput sitm``tput dim`-" Change selection: [up/down]  Select: [ENTER]" `tput sgr0`
    local selected="$1"; shift

    ESC=`echo -e "\033"`
    cursor_blink_on()  { tput cnorm; }
    cursor_blink_off() { tput civis; }
    cursor_to()        { tput cup $(($1-1)); }
    print_option()     { echo  `tput dim` "   $1" `tput sgr0`; }
    print_selected()   { echo `tput bold` "=> $1" `tput sgr0`; }
    get_cursor_row()   { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }
    key_input()        { read -s -n3 key 2>/dev/null >&2; [[ $key = $ESC[A ]] && echo up; [[ $key = $ESC[B ]] && echo down; [[ $key = "" ]] && echo enter; }

    for opt; do echo; done

    local lastrow=`get_cursor_row`
    local startrow=$(($lastrow - $#))
    # trap "cursor_blink_on; echo; echo; exit" 2
    cursor_blink_off

    : selected:=0

    while true; do
        local idx=0
        for opt; do
            cursor_to $(($startrow + $idx))
            if [ $idx -eq $selected ]; then
                print_selected "$opt"
            else
                print_option "$opt"
            fi
            ((idx++))
        done

        case `key_input` in
            enter) break;;
            up)    ((selected--)); [ $selected -lt 0 ] && selected=$(($# - 1));;
            down)  ((selected++)); [ $selected -ge $# ] && selected=0;;
        esac
    done

    cursor_to $lastrow
    cursor_blink_on
    echo

    return $selected
}

function mainMenuList() {
    _listApps="Apps"
    options=("Latest News" "Device Management" "$_listApps" "Exit");
    menuPicker "Choose:" 0 "${options[@]}"; choice=$?
    # if [ "${options[$choice]}" == one ]; then
    #      appdb_news
    #      echo
    #      mainMenu "Choose:" 0 "${options[@]}"; choice=$?

    # fi

    case "${options[$choice]}" in
        "Latest News")
                clear;
                echo -e "Fetching Latest News\n"
                appdb_news
                # cursor_blink_off
                echo
        ;;
        "Device Management")
                clear;
                linkDeviceList;
        ;;
        "$_listApps")
                clear;
                __listAllApps;
        ;;
        "Exit")
                exit;
        ;;
    esac
}

function linkDeviceList() {
    options=("Authorize w/ Email" "Authorize w/ Code" "Generate a Code" "List Devices" "Device Job Status" "DeAuthorize" "Exit")
    menuPicker "Choose:" 0 "${options[@]}"; choice=$?
    # echo "${options[$choice]}" selected
    case "${options[$choice]}" in
        "Authorize w/ Email")
            echo -e "*[Enter your Linked Email]"
            read _email;
            _rCode=$(curl -Ss -X POST --globoff -F "action=link" -F "type=control" -F "email="$_email"" "$_appdbAPI" | jq -r .errors[]);
            # echo $_rCode;
            if [ "$_rCode" == "ERROR_PROCEED_TO_EMAIL" ]; then
                echo -e "\n- An Email has been sent to you. Restart the script and choose \"Authorize w/ Code\"\n"
            else
                echo -e "\n- An Error Has Occurred."
                echo "$_rCode"
            fi
        ;;
        "Authorize w/ Code")
            echo -e "*[Enter Code]"
            read _rCode
            appdb_link "$_rCode" > .appdblink
                if [ -s "$_lt_Config" ]; then
                    echo -e "\nDone\n";
                fi

        ;;
        "Generate a Code")
                if [ -z "$_linkingTicket" ]; then
                    echo -e `tput setaf 1`ERROR: You Need to Authorize Usage Device First."\n"`tput sgr0`
                else
                    _rCode=$(curl -Ss -X POST --globoff -F "action=get_link_code" -b "lt="$_linkingTicket"" "$_appdbAPI" | jq -r .data);
                    echo -e "- Your Code is: "`tput setaf 2`$_rCode"\n"`tput sgr0`
                fi
        ;;
        "List Devices")
                        if [ -n "$_linkingTicket" ]; then
                            appdb_devices;
                            _numOfDevices=$(cat $_devices_list | jq -r .total);
                            echo total Devices: $_numOfDevices;
                            for((i=0;i<$_numOfDevices;i++)); do
                                echo
                                echo -e "Device Name: "`cat devicedata.json | jq -r '.data | .['$i'] | .name'`
                                echo -e "Model: "`cat devicedata.json | jq -r '.data | .['$i'] | .nice_idevice_model'`
                                echo -e "iOS Version: "`cat devicedata.json | jq -r '.data | .['$i'] | .ios_version'`
                                echo -e "PRO User: "`cat devicedata.json | jq -r '.data | .['$i'] | .is_pro'`
                                echo -e "PRO Expiration Date: "`cat devicedata.json | jq -r '.data | .['$i'] | .pro_till'`
                                echo -e "PRO Provider: "`cat devicedata.json | jq -r '.data | .['$i'] | .pro_provider'`
                                echo -e "PRO Support: "`cat devicedata.json | jq -r '.data | .['$i'] | .pro_support_uri'`
                                echo
                            done
                        else
                            echo -e `tput setaf 1`ERROR: You Need to Authorize Usage Device First."\n"`tput sgr0`
                        fi
        ;;
        "Device Job Status")
                            __fetchLatestCommands;
        ;;
        "DeAuthorize")
                        echo - "Are You Sure? (Y/N)";
                        read -n1 _choice;
                        if [[ $_choice == [yY] ]]; then
                            rm $_lt_Config;
                            if [[ $? == 0 ]]; then
                                echo -e "\nSuccess \n"
                            fi
                        else
                            echo -e "You Didn't Choose";
                        fi

        ;;
        "Exit")
                echo
        ;;
    esac
}

function __listAllApps() {
    options=("Top iOS" "Top Cydia" "Latest iOS" "Latest Cydia" "Search" "Exit");
    menuPicker "Choose:" 0 "${options[@]}"; choice=$?

    case "${options[$choice]}" in
        "Top iOS")
                    clear;
                    _top=1
                    __top_ios_day 1;
                    __listIosApps
                    echo
        ;;
        "Top Cydia")
                    clear;
                    _top=1
                    __top_cydia_day 1;
                    __listCydiaApps;
        ;;
        "Latest iOS")
                    clear;
                    __latest_ios 1;
                    __listIosApps;
        ;;
        "Latest Cydia")
                    clear;
                    __latest_cydia 1;
                    __listCydiaApps;
        ;;
        "Search")
                __search;
        ;;
        "Exit")
                exit;
        ;;
    esac

}

function __listIosApps() {
    local _i=1;
    local _j=0;
    _iosListLocation="listing/ios_page1.json"
    # __top_ios_day $_i;
    while [ true ]; do
        while (( $_j <= 4 )); do
        # set -x
             local _name$_j="`cat "$_iosListLocation" | jq -r '.data | .['$_j'] | .name'`";
            ((_j++));
        done
        # local _name0=`cat listing/ios_page1.json | jq -r '.data | .[0] | .name'`;
        # local _name1=`cat listing/ios_page1.json | jq -r '.data | .[1] | .name'`;
        # local _name2=`cat listing/ios_page1.json | jq -r '.data | .[2] | .name'`;
        # local _name3=`cat listing/ios_page1.json | jq -r '.data | .[3] | .name'`;
        # local _name4=`cat listing/ios_page1.json | jq -r '.data | .[4] | .name'`;
        # echo waitiing
        # read ok
        local options=("$_name0" "$_name1" "$_name2" "$_name3" "$_name4" "`echo`" "Next Page" "Exit");
        menuPicker "Choose:" 0 "${options[@]}"; choice=$?

        case "${options[$choice]}" in
            "$_name0")
                        clear;
                        __appPage 0 "$_iosListLocation" "ios";
                        echo
            ;;
            "$_name1")
                        clear;
                        __appPage 1 "$_iosListLocation" "ios";
                        echo
            ;;
            "$_name2")
                        clear;
                        __appPage 2 "$_iosListLocation" "ios";
                        echo
            ;;
            "$_name3")
                        clear;
                        __appPage 3 "$_iosListLocation" "ios";
                        echo
            ;;
            "$_name4")
                        clear;
                        __appPage 4 "$_iosListLocation" "ios";
                        echo
            ;;
            "Next Page")
                        clear;
                        # echo i = $_i;
                        # echo
                        _j=0;
                        _i=$((_i + 1))
                        # echo i = $_i;
                        # echo
                        if (( _top == 1 )); then
                            __top_ios_day $_i;
                        elif (( _search == 1 )); then
                            __search_ios $_i $searchTerm;
                        else
                            __latest_ios $_i;
                        fi


            ;;
            "Exit")
                        echo "Exit"
                        break;

            ;;
        esac
        # echo -e "Version: "`cat ios_page1.json | jq -r '.data | .['$i'] | .version'`
        # echo -e "Price: "`cat ios_page1.json | jq -r '.data | .['$i'] | .price'`
        # echo -e "Compatibility: "`cat ios_page1.json | jq -r '.data | .['$i'] | .is_compatible | .result'`
        # echo -e "Description: "`cat ios_page1.json | jq -r '.data | .['$i'] | .description'`
        # echo -e "Description: "`cat ios_page1.json | jq -r '.data | .['$i'] | .image'`
        echo
    done
}

function __listCydiaApps() {
    local _i=1;
    local _j=0;
    _cydiaListLocation="listing/cydia_page1.json"
    # __top_cydia_day $_i;
    while [ true ]; do
        # curl -Ss -o out"$i".jpg "`cat ios_page1.json | jq -r '.data | .['$i'] | .image'`" && catimg -w 60 -r 2 out"$i".jpg

        while (( $_j <= 4 )); do
        # set -x
             local _name$_j="`cat "$_cydiaListLocation" | jq -r '.data | .['$_j'] | .name'`";
            ((_j++));
        done
        # local _name0=`cat listing/ios_page1.json | jq -r '.data | .[0] | .name'`;
        # local _name1=`cat listing/ios_page1.json | jq -r '.data | .[1] | .name'`;
        # local _name2=`cat listing/ios_page1.json | jq -r '.data | .[2] | .name'`;
        # local _name3=`cat listing/ios_page1.json | jq -r '.data | .[3] | .name'`;
        # local _name4=`cat listing/ios_page1.json | jq -r '.data | .[4] | .name'`;
        # echo waitiing
        # read ok
        local options=("$_name0" "$_name1" "$_name2" "$_name3" "$_name4" "`echo`" "Next Page" "Exit");
        menuPicker "Choose:" 0 "${options[@]}"; choice=$?

        case "${options[$choice]}" in
            "$_name0")
                        clear;
                        __appPage 0 "$_cydiaListLocation" "cydia";
                        echo
            ;;
            "$_name1")
                        clear;
                        __appPage 1 "$_cydiaListLocation" "cydia";
                        echo
            ;;
            "$_name2")
                        clear;
                        __appPage 2 "$_cydiaListLocation" "cydia";
                        echo
            ;;
            "$_name3")
                        clear;
                        __appPage 3 "$_cydiaListLocation" "cydia";
                        echo
            ;;
            "$_name4")
                        clear;
                        __appPage 4 "$_cydiaListLocation" "cydia";
                        echo
            ;;
            "Next Page")
                        clear;
                        # echo i = $_i;
                        # echo
                        _j=0;
                        _i=$((_i + 1))
                        # echo i = $_i;
                        # echo
                        if (( _top == 1 )); then
                            __top_cydia_day $_i;
                        elif (( _search == 1 )); then
                            __search_cydia $_i $searchTerm;
                        else
                            __latest_cydia $_i;
                        fi
            ;;
            "Exit")
                        echo "Exit"
                        break;

            ;;
        esac
        # echo -e "Version: "`cat ios_page1.json | jq -r '.data | .['$i'] | .version'`
        # echo -e "Price: "`cat ios_page1.json | jq -r '.data | .['$i'] | .price'`
        # echo -e "Compatibility: "`cat ios_page1.json | jq -r '.data | .['$i'] | .is_compatible | .result'`
        # echo -e "Description: "`cat ios_page1.json | jq -r '.data | .['$i'] | .description'`
        # echo -e "Description: "`cat ios_page1.json | jq -r '.data | .['$i'] | .image'`
        echo
    done
}

function __appPage() {
    _listLocation="$2"
    _type="$3";
    while [ true ]; do
            curl -Ss -o listing/out"$i".jpg "`cat $_listLocation | jq -r '.data | .['$1'] | .image'`" && ./catimg -t -w 60 -r 2 listing/out"$i".jpg
            echo "Name: " `tput setaf 4` `cat $_listLocation | jq -r '.data | .['$1'] | .name'` `tput sgr0`
            # echo -e "Name: "`cat listing/ios_page1.json | jq -r '.data | .['$1'] | .name'`
            echo "Version: " `tput setaf 4``cat $_listLocation | jq -r '.data | .['$1'] | .version'``tput sgr0`
            # echo -e "Version: "`cat listing/ios_page1.json | jq -r '.data | .['$1'] | .version'`
            echo "Price: " `tput setaf 4``cat $_listLocation | jq -r '.data | .['$1'] | .price'``tput sgr0`
            # echo -e "Price: "`cat listing/ios_page1.json | jq -r '.data | .['$1'] | .price'`
            # echo -e "Compatibility: "`cat listing/ios_page1.json | jq -r '.data | .['$1'] | .is_compatible | .result'`
            local _compatible=`cat $_listLocation | jq -r '.data | .['$1'] | .is_compatible | .result'`;
            local _reason=`cat $_listLocation | jq -r '.data | .['$1'] | .is_compatible | .reason'`;
            if [ "$_compatible" = yes ]; then
                    echo "Compatible: " `tput setaf 2`"$_compatible"`tput sgr0`
                    echo "Notice: " `tput setaf 1`"Compatibility Checks Disabled"`tput sgr0`
            elif [ "$_compatible" = unknown ]; then
                    echo "Compatible: " `tput setaf 2`"Yes"`tput sgr0`
            else
                    echo "Compatible: " `tput setaf 1`"$_compatible"`tput sgr0`
                    echo "Reason: " `tput setaf 1`"$_reason"`tput sgr0`
            fi

            # cat listing/ios_page1.json | jq -r '.data | .['$1'] | .description' | sed -e 's/\<br\>/ /g' -e 's/\<br \/\>/ /g';
            echo
            _appid=`cat $_listLocation | jq -r '.data | .['$1'] | .id'`

            options=("`echo`" "`echo`" "Install" "Go Back" "Exit");
            menuPicker "Choose:" 2 "${options[@]}"; choice=$?

            case "${options[$choice]}" in
                "Install")
                            clear;
                            __appVersions $_type $_appid;
                            # __appVersions ios 1133544923;

                ;;
                "Go Back")
                        clear;
                        break;
                ;;
                "Exit")
                        exit;
                ;;
            esac
    done
}

function __appVersions(){
    echo
    local _type="$1"
    __getLinks "$_type" "$2"
    # local _k=0;
    while [ true ]; do
        cat listing/links.json | jq -r '.data[] | 'keys[]'' > listing/list.txt

        while read line; do
            # if (( _k < 6 )); then
                arr+=($line);
        #     fi
        # ((_k++))
        done < listing/list.txt


        IFS=$'\n' sortedVersions=($(sort -Vr <<<"${arr[*]}")); unset IFS

        for((_k=0;_k<6;_k++)); do
            finalVersions+=(${sortedVersions[$_k]})
        done



        finalVersions=("${finalVersions[@]}" "`echo`" "Go Back" "Exit")
        # sorted=("one" "two" "three")
        echo -e "*[Available Links]:"
        menuPicker "Choose:" 0 "${finalVersions[@]}"; choice=$?
        # echo "${sorted[$choice]}" selected

        if [ "${finalVersions[$choice]}" = "Go Back" ]; then
            unset arr;
            unset sortedVersions;
            unset finalVersions;
            break;
        elif [ "${finalVersions[$choice]}" = "Exit" ]
            then
                exit;
        fi


        clear;
        echo "version : "${finalVersions[$choice]}
        __listAppLinks "${finalVersions[$choice]}" "$_type";
        unset arr;
        unset sortedVersions;
        unset finalVersions;
        _k=0;
        rm listing/list.txt
    done
}

function __listAppLinks(){
    # echo i = $_i;
    local _i=0
    # echo $1
    # echo i = $_i;
    local _type="$2";
    while [ true ]; do
        _linksOptions=("Install" "Custom Install" "Next Link" "Go Back")
        _verfStatus=`cat listing/links.json | jq -r '.data[] | ."'$1'"['$_i'] | ."verified"'`
        _linkID=`cat listing/links.json | jq -r '.data[] | ."'$1'"['$_i'] | ."id"'`
        if [ "$_verfStatus" != null ]; then

        echo "Host: "`tput setaf 4``cat listing/links.json | jq -r '.data[] | ."'$1'"['$_i'] | ."host"'``tput sgr0`
        echo "Cracker: "`tput setaf 4``cat listing/links.json | jq -r '.data[] | ."'$1'"['$_i'] | ."cracker"'``tput sgr0`
        echo "Uploader: "`tput setaf 4``cat listing/links.json | jq -r '.data[] | ."'$1'"['$_i'] | ."uploader_name"'``tput sgr0`
            if [ "$_verfStatus" != true ]; then
                echo "Verified: " `tput setaf 1`"$_verfStatus"`tput sgr0`
            else
                echo "Verified: " `tput setaf 2`"$_verfStatus"`tput sgr0`
                echo
            fi
        else
            echo `tput setaf 1`No More Links`tput sgr0`
            # unset ${options['Next Link']}
            _linksOptions=("Go Back")

        fi
        # cat listing/links.json | jq -r '.data[] | ."'$1'"['$_i'] | ."host"'
        # cat listing/links.json | jq -r '.data[] | ."'$1'"['$_i'] | ."cracker"'
        # cat listing/links.json | jq -r '.data[] | ."'$1'"['$_i'] | ."uploader_name"'
        # cat listing/links.json | jq -r '.data[] | ."'$1'"['$_i'] | ."verified"'


        menuPicker "Choose:" 0 "${_linksOptions[@]}"; choice=$?
        #  echo "${options[$choice]}" selected
            # _i=$((_i + 1))
        case "${_linksOptions[$choice]}" in
            "Install")
                echo "Attempting Installation..."
                local _revokeID=__getRevokeID;
                sleep 2
                local _check=`__defaultInstall "$_linkID" "$_type" "$_revokeID" | jq -r .success`;
                if [ "$_check" = true ]; then
                    echo Successful
                    echo
                    __fetchLatestCommands;
                    break;
                fi
                echo
            ;;
            "Custom Install")
                # echo -e "Set a Custom BundleID? (y/n)\n"
                # read -n1 _custID;
                # if [ "$_custID" = y ]; then
                    echo -e "\nEnter a 4 Letter Custom ID: "
                    read -n5 _custBundleID;
                # else
                #     _custBundleID="";
                # fi
                # echo -e "Set a Custom Display Name? (y/n)\n"
                # read -n1 _custDisp;
                # if [ "$_custDisp" = y ]; then
                    echo -e "\nEnter a New Display Name: "
                    read _custDisplayName;
                # else
                #     _custDisplayName="";
                # fi
                echo
                echo "Attempting Installation..."
                local _revokeID=__getRevokeID;
                sleep 2
                local _check=`__customInstall "$_linkID" "$_type" "$_revokeID" "$_custBundleID" "$_custDisplayName" | jq -r .success`;
                if [ "$_check" = true ]; then
                    echo Successful
                    echo
                    __fetchLatestCommands;
                    break;
                else
                    echo Failed
                    echo
                    __fetchLatestCommands;
                    break;
                fi
                echo
            ;;
            "Next Link")
                        clear;
                        # echo i = $_i;
                        _i=$((_i + 1));
                        # echo i = $_i;
                        # __listAppLinks $1
                        # echo i = $_i;

            ;;
            "Go Back")
                    clear;
                    break;
            ;;
        esac

    done

}

function __search(){
    options=("Search iOS Apps" "Search Cydia Apps" "Exit")
    menuPicker "Choose:" 0 "${options[@]}"; choice=$?
    # echo "${options[$choice]}" selected
    case "${options[$choice]}" in
        "Search iOS Apps")
                    __search_iOS_Main
        ;;
        "Search Cydia Apps")
                    __search_Cydia_Main
        ;;
        "Exit")
                    exit;
        ;;
    esac
}
function __search_iOS_Main(){
    echo -e "Enter Your Search Term"
    read searchTerm;
    _search=1
    __search_ios 1 $searchTerm;
    __listIosApps;
}
function __search_Cydia_Main(){
    echo -e "Enter Your Search Term"
    read searchTerm;
    _search=1;
    __search_cydia 1 $searchTerm;
    __listCydiaApps;
}

if [ ! -f "$_lt_Config" ]; then
    linkDeviceList;
    exit;
fi

mainMenuList;
