#!/bin/bash
# Usage: ./task1.sh path/to/accounts.csv

input_file="$1"
output_file="accounts_new.csv"

# Ensure an input file is provided
if [[ -z "$input_file" || ! -f "$input_file" ]]; then
  echo "Usage: $0 path/to/accounts.csv"
  exit 1
fi

# Initialize an associative array for counting email bases
declare -A base_counts
# Read the entire file into an array (preserving quotes and commas)
mapfile -t lines < "$input_file"

# Write header directly to output (assuming first line is header)
echo "${lines[0]}" > "$output_file"

# First pass: count base email occurrences
for ((i=1; i<${#lines[@]}; i++)); do
  line="${lines[i]}"
  # Skip empty lines if any
  [[ -z "$line" ]] && continue

  # Remove Windows-style CR if present
  line="${line%$'\r'}"

  # Extract fields without breaking quoted commas:
  # 1. Department (last field after last comma)
  dept="${line##*,}"
  # 2. Remove dept from line (including the comma before it)
  if [[ -n "$dept" ]]; then
    line_no_dept="${line%,$dept}"
  else
    line_no_dept="${line::-1}"   # remove last comma if dept is empty
  fi
  # 3. Email (now last field in line_no_dept after its last comma)
  email_old="${line_no_dept##*,}"
  # 4. Remove email field (including comma) from the line
  if [[ -n "$email_old" ]]; then
    line_no_email="${line_no_dept%,$email_old}"
  else
    line_no_email="${line_no_dept::-1}"  # remove trailing comma if email was empty
  fi

  # Now line_no_email is "id,location_id,name,title"
  # Extract simple fields:
  id="${line_no_email%%,*}"                            # text before first comma
  rest_after_id="${line_no_email#"$id,"}"              # remove "id," prefix
  loc="${rest_after_id%%,*}"                           # next field before next comma
  rest_after_loc="${rest_after_id#"$loc,"}"            # remove "loc," prefix
  name="${rest_after_loc%%,*}"                         # next field (name) before comma
  # Everything after name comma is the title (could include quotes and comma inside)
  title_field="${rest_after_loc#"$name,"}"             # this preserves quotes around title if any

  # Format the name (capitalize first letters of each word)
  name_lower=$(echo "$name" | tr '[:upper:]' '[:lower:]')
  formatted_name=$(echo "$name_lower" | sed -E 's/(^|[ -])(\w)/\1\U\2/g')

  # Build email base: first letter of first name + surname (last name)
  first_initial="${formatted_name:0:1}"
  if [[ "$formatted_name" == *" "* ]]; then
    last_name="${formatted_name##* }"
  else
    last_name="$formatted_name"
  fi
  base=$(echo "${first_initial}${last_name}" | tr '[:upper:]' '[:lower:]')
  base_counts["$base"]=$(( ${base_counts["$base"]} + 1 ))

  # Store the processed components for second pass output
  # (Using an array of strings; we'll use a placeholder for email here)
  lines[i]="$id,$loc,$formatted_name,$title_field,BASE:${base},$dept"
done

# Second pass: generate output lines with proper emails
for ((i=1; i<${#lines[@]}; i++)); do
  entry="${lines[i]}"
  [[ -z "$entry" ]] && continue  # skip if any empty (shouldn't happen after above)
  # Extract the placeholder base from the entry
  base=$(grep -oP '(?<=BASE:)[^,]+' <<< "$entry")
  # Determine final email (append location_id if base is duplicate)
  if [[ ${base_counts[$base]} -gt 1 ]]; then
    loc_field=$(echo "$entry" | cut -d, -f2)
    email_final="${base}${loc_field}@abc.com"
  else
    email_final="${base}@abc.com"
  fi
  # Replace the BASE:placeholder with the real email
  output_line="${entry/BASE:$base/$email_final}"
  echo "$output_line" >> "$output_file"
done

echo "New file created: $output_file"
