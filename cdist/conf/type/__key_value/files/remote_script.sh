#!/bin/sh

export key="$(cat "$__object/parameter/key" 2>/dev/null \
   || echo "$__object_id")"
export state="$(cat "$__object/parameter/state")"

file="$(cat "$__object/parameter/file")"

export delimiter="$(cat "$__object/parameter/delimiter")"
export value="$(cat "$__object/parameter/value" 2>/dev/null \
   || echo "__CDIST_NOTSET__")"
if [ -f "$__object/parameter/exact_delimiter" ]; then
    export exact_delimiter=1
else
    export exact_delimiter=0
fi

tmpfile=$(mktemp "${file}.cdist.XXXXXXXXXX")
# preserve ownership and permissions by copying existing file over tmpfile
if [ -f "$file" ]; then
    cp -p "$file" "$tmpfile"
else
    touch "$file"
fi
awk -f - "$file" >"$tmpfile" <<"AWK_EOF"
BEGIN {
    # import variables in a secure way ..
    state=ENVIRON["state"]
    key=ENVIRON["key"]
    delimiter=ENVIRON["delimiter"]
    value=ENVIRON["value"]
    comment=ENVIRON["comment"]
    exact_delimiter=ENVIRON["exact_delimiter"]
    inserted=0
    lastline=""
    lastlinepopulated=0
    line=key delimiter value
}
# enter the main loop
{
    # I dont use regex, this is by design, so we can match against every value without special meanings of chars ...
    i = index($0,key)
    if(i == 1) {
        delval = substr($0,length(key)+1)
        delpos = index(delval,delimiter)
        if(delpos > 1) {
            spaces = substr(delval,1,delpos-1)
            sub(/[ \t]*/,"",spaces)
            if( length(spaces) > 0 ) {
                # if there are not only spaces between key and delimiter,
                # continue since we we are on the wrong line
                if(lastlinepopulated == 1) {
                    print lastline
                }
                lastline=$0
                lastlinepopulated=1
                next
            }
        }
        if(state == "absent") {
            if(lastline == comment) {
                # if comment is present, clear lastlinepopulated flag
                lastlinepopulated=0
            }
            # if absent, simple yump over this line
            next
        }
        else {
            # if comment is present and not present in last line
            if (lastlinepopulated == 1) {
                print lastline
                if( comment != "" && lastline != comment) {
                    print comment
                }
                lastlinepopulated=0
            }
            inserted=1
            # state is present, so insert correct line here
            print line
            lastline=line
            next
        }
    }
    else {
        if(lastlinepopulated == 1) {
            print lastline
        }
        lastline=$0
        lastlinepopulated=1
    }
}
END {
    if(lastlinepopulated == 1) {
        print lastline
    }
    if(inserted == 0 && state == "present" ) {
        if(comment != "" && lastline != comment){
            print comment
        }
        print line
    }
}
AWK_EOF
mv -f "$tmpfile" "$file"
