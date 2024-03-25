FUNCTION ZFM_BM_PDF_TO_TEXT.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  EXPORTING
*"     REFERENCE(ET_FILE_CONTENT) TYPE  ZTT_BM_TEXT
*"  CHANGING
*"     REFERENCE(C_PDF_PATH) TYPE  ICL_DIAGFILENAME OPTIONAL
*"----------------------------------------------------------------------
  DATA:
    LW_TOOL_PATH  TYPE STRING,
    LPW_CONVERTED TYPE XMARK,
    LS_ENTRY      TYPE CST_RSWATCH01_ALV.

* Get client tool
  PERFORM GET_CLIENT_TOOL CHANGING LW_TOOL_PATH.

* Get front file if need
  PERFORM GET_PDF_FRONTEND
    CHANGING C_PDF_PATH.

* Run client tool to convert pdf file to text file
  PERFORM RUN_CLIENT_TOOL
    USING LW_TOOL_PATH C_PDF_PATH
    CHANGING LPW_CONVERTED.

* Run client tool to convert pdf file to text file\
  PERFORM READ_TEXT_FILE
    USING C_PDF_PATH
    CHANGING ET_FILE_CONTENT.

* Copy
  perform COPY_FILE using C_PDF_PATH.

ENDFUNCTION.
