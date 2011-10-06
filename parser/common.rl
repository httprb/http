%%{

  machine common;

  # ==== TOKENS ====

        CRLF = "\r\n";
         CTL = (cntrl | 127);
        LWSP = " " | "\t";
         LWS = CRLF ? LWSP *;
        TEXT = any -- CTL;
        LINE = TEXT -- CRLF;
  separators = "(" | ")" | "<" | ">" | "@" | "," | ";"
             | ":" | "\\" | "\"" | "/" | "[" | "]"
             | "?" | "=" | "{" | "}" | " " | "\t"
             ;
       token = TEXT -- separators;

  # ==== HEADERS ====

         header_sep = LWSP * ":" LWSP *;
         header_eol = LWSP * CRLF;
            ws_line = LWSP +;
         no_ws_line = ( LINE -- LWSP ) + % end_header_value_no_ws;
         blank_line = "" % end_header_value_no_ws;
     non_blank_line = no_ws_line ( ws_line no_ws_line) * ws_line ?;
  header_value_line = ( blank_line | non_blank_line )
                    > start_header_value_line
                    % end_header_value_line
                    ;

  header_value_line_1 = header_value_line CRLF;
  header_value_line_n = LWSP + <: header_value_line_1;
         header_value = header_value_line_1 header_value_line_n *;
  generic_header_name = token +
                          > start_header_name
                          % end_header_name;


}%%