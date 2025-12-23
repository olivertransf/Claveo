#!/bin/bash
echo "
---------- { Notice } ----------
 _  _ _  _  _ _  _ 
|_)| | |(/_| (_|(/_     
|             _|   

Please use this script for private use only, not commercial use.
Usage: ./pmerge_macos.sh \"path/to/myfile.pdf\"
 
Debug mode: Edit the first line of this file to: #!/bin/bash -x . You can also disable cleanup by removing the last few lines of this script.
--------------------------------
"

# Get absolute path (macOS compatible)
if [[ "$1" = /* ]]; then
    path="$1"
else
    path="$PWD/$1"
fi

shelldir=$PWD
file=$(basename "${path}")
dir=$(dirname "${path}")
cd "$dir"

# Check for p2mp
if ! command -v p2mp &> /dev/null; then
    echo "ERROR: p2mp not found. Please install PDFtoMusic Pro."
    echo "You may need to run: sudo ./pdftomusicpro-1.7.1d.0.run"
    echo "Or install p2mp manually to /usr/local/bin/p2mp"
    exit 1
fi

# Check for MuseScore (macOS)
MUSESCORE_CMD=""
if [ -f "/Applications/MuseScore 4.app/Contents/MacOS/mscore" ]; then
    MUSESCORE_CMD="/Applications/MuseScore 4.app/Contents/MacOS/mscore"
elif [ -f "/Applications/MuseScore 3.app/Contents/MacOS/mscore" ]; then
    MUSESCORE_CMD="/Applications/MuseScore 3.app/Contents/MacOS/mscore"
elif command -v musescore &> /dev/null; then
    MUSESCORE_CMD="musescore"
else
    echo "ERROR: MuseScore not found. Please install MuseScore from https://musescore.org"
    exit 1
fi

mkdir -p musicxml
echo "Directory $PWD"

# Decrypt PDF if needed (qpdf handles both encrypted and unencrypted PDFs)
if command -v qpdf &> /dev/null; then
    qpdf --decrypt "$file" "decrypted.pdf" 2>/dev/null || cp "$file" "decrypted.pdf"
else
    cp "$file" "decrypted.pdf"
fi

# Get page count
if command -v pdftk &> /dev/null; then
    pages=$(pdftk "decrypted.pdf" dump_data 2>/dev/null | grep NumberOfPages | sed 's/[^0-9]*//')
else
    # Fallback: try to get page count using other methods
    pages=$(python3 -c "import PyPDF2; f=open('decrypted.pdf','rb'); pdf=PyPDF2.PdfReader(f); print(len(pdf.pages)); f.close()" 2>/dev/null || echo "1")
fi

if [ -z "$pages" ] || [ "$pages" -eq 0 ]; then
    echo "Warning: Could not determine page count, assuming 1 page"
    pages=1
fi

echo "[INFO]: Found $pages pages"

for ((i = 1 ; i <= $pages ; i++)); do
    echo "----------[ Parsing page $i of $pages ]----------"
    # Generate page
    if command -v pdftk &> /dev/null; then
        pdftk "decrypted.pdf" cat "$i" output "out$i.pdf"
    else
        # Fallback: use the whole PDF if pdftk not available
        if [ $i -eq 1 ]; then
            cp "decrypted.pdf" "out$i.pdf"
        else
            echo "Warning: pdftk not available, cannot split pages. Processing whole PDF."
            break
        fi
    fi
    
    # Create XML (Music XML) files using p2mp
    p2mp "out$i.pdf" -format XML -pathdest "$PWD/musicxml/" >> log.txt 2>&1
    
    # Convert XML to MSCX using MuseScore
    if [ -f "$PWD/musicxml/out$i.xml" ]; then
        "$MUSESCORE_CMD" -o "$PWD/musicxml/out$i.mscx" "$PWD/musicxml/out$i.xml" 2>>log.txt
    else
        echo "Warning: XML file not generated for page $i"
    fi
done

echo "----------[ Cleanup p2mp ]----------"
# Cleanup temp pdf & individual mid
rm -rf out*.pdf
rm -rf decrypted.pdf
rm -rf out*.mid

# Combine musescore's mscx files
cd musicxml
if [ $pages -gt 0 ]; then
    mscxarr=( $(printf 'out%d.mscx\n' $(seq 1 $pages)) )
    # Check if files exist before merging
    existing_files=()
    for f in "${mscxarr[@]}"; do
        if [ -f "$f" ]; then
            existing_files+=("$f")
        fi
    done
    
    if [ ${#existing_files[@]} -gt 0 ]; then
        python3 "$shelldir/mxcat.py" "${existing_files[@]}" > "$dir/result.mscx" 2>>../log.txt
        
        # Convert final mscx to a compressed format
        "$MUSESCORE_CMD" -o "$dir/result_compressed.mscz" "$dir/result.mscx" 2>>../log.txt
        
        # Generate high-quality MuseScore midi
        "$MUSESCORE_CMD" -o "$dir/result.mid" "$dir/result.mscx" 2>>../log.txt
        
        echo "✓ Conversion complete!"
        echo "  MIDI file: $dir/result.mid"
        echo "  MuseScore file: $dir/result.mscx"
    else
        echo "Error: No MSCX files were generated. Check log.txt for details."
        exit 1
    fi
fi

echo "----------[ Cleanup mscore3 ]----------"
# Cleanup individual mid, but must keep XML files!
rm -rf out*.mid

cd "$dir"
echo "Done! Output files:"
ls -lh result.* 2>/dev/null || echo "No result files found. Check log.txt for errors."

