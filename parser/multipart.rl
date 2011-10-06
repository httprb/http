%%{

  machine multipart;

  include common "common.rl";

  bchar = alnum | "'" | "(" | ")" | "+" | "_" | ","
        | "-" | "." | "/" | ":" | "=" | "?"
        ;


      final = "--" @ end_parts ;
    padding = final ? LWSP * CRLF;

  # ==== HEADERS ====
  header_name = generic_header_name;
       header = header_name header_sep header_value % end_header_value;
      headers = header * CRLF;

  multipart =
    start:
      any * $ peek_delimiter,

    delimiter:
      any * $ parse_delimiter,

    head:
      padding
      headers
        > start_head
        % end_head
      -> body,

    body:
      any * $ peek_delimiter,

    epilogue: any *;

  main := multipart $! something_went_wrong;

}%%