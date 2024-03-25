*----------------------------------------------------------------------*
***INCLUDE LZFG_PDF_LIBF01.

*----------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Form GET_CLIENT_TOOL
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      <-- LW_TOOL_PATH
*&---------------------------------------------------------------------*
FORM GET_CLIENT_TOOL
  CHANGING LPW_TOOL_PATH TYPE STRING.

  TYPES: BEGIN OF TYP_BIN,
           LINE TYPE X LENGTH 255,
         END OF TYP_BIN.

  DATA: LW_PATH              TYPE STRING,
        LW_PDF2TEXT          TYPE STRING,
        LW_RESULT            TYPE ABAP_BOOL,
        LW_SERVER_DIR        TYPE CHAR255,
        LPW_TOOL_SERVER_PATH TYPE STRING,
        LW_DOWN_PATH         TYPE STRING,
        LW_LINE_LEN          TYPE I,
        LW_FILE_LEN          TYPE I,
        LT_TOOL_BINARY       TYPE STANDARD TABLE OF TYP_BIN,
        LS_LINE              LIKE LINE OF LT_TOOL_BINARY.

  IF LPW_TOOL_PATH IS INITIAL.
*   Get SAP GUI Working Directory
    CALL METHOD CL_GUI_FRONTEND_SERVICES=>GET_SAPGUI_WORKDIR
      CHANGING
        SAPWORKDIR            = LW_PATH
      EXCEPTIONS
        GET_SAPWORKDIR_FAILED = 1
        CNTL_ERROR            = 2
        ERROR_NO_GUI          = 3
        NOT_SUPPORTED_BY_GUI  = 4
        OTHERS                = 5.

    IF LW_PATH IS INITIAL.
*     Get Temporary Directory
      CALL METHOD CL_GUI_FRONTEND_SERVICES=>GET_TEMP_DIRECTORY
        CHANGING
          TEMP_DIR             = LW_PATH
        EXCEPTIONS
          CNTL_ERROR           = 1
          ERROR_NO_GUI         = 2
          NOT_SUPPORTED_BY_GUI = 3
          OTHERS               = 4.
    ENDIF.

    IF LW_PATH IS INITIAL.
*     Get Upload Download Directory
      CALL METHOD CL_GUI_FRONTEND_SERVICES=>GET_UPLOAD_DOWNLOAD_PATH
        CHANGING
          UPLOAD_PATH                 = LW_PATH
          DOWNLOAD_PATH               = LW_DOWN_PATH
        EXCEPTIONS
          CNTL_ERROR                  = 1
          ERROR_NO_GUI                = 2
          NOT_SUPPORTED_BY_GUI        = 3
          GUI_UPLOAD_DOWNLOAD_PATH    = 4
          UPLOAD_DOWNLOAD_PATH_FAILED = 5
          OTHERS                      = 6.
    ENDIF.

    IF LW_PATH IS INITIAL.
      MESSAGE S001(ZMS_PDF) DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    CONCATENATE LW_PATH 'pdftotext.exe' INTO LW_PDF2TEXT SEPARATED BY '\'.
  ELSE.

    LW_PDF2TEXT     = LPW_TOOL_PATH.
  ENDIF.
  CLEAR: LPW_TOOL_PATH.

* Check PDF Tool is exists
  CALL METHOD CL_GUI_FRONTEND_SERVICES=>FILE_EXIST
    EXPORTING
      FILE                 = LW_PDF2TEXT
    RECEIVING
      RESULT               = LW_RESULT
    EXCEPTIONS
      CNTL_ERROR           = 1
      ERROR_NO_GUI         = 2
      WRONG_PARAMETER      = 3
      NOT_SUPPORTED_BY_GUI = 4
      OTHERS               = 5.

  IF LW_RESULT EQ ABAP_TRUE.
*   Tool is exist in client, no need to get from server
    LPW_TOOL_PATH = LW_PDF2TEXT.
    RETURN.
  ENDIF.

  CLEAR LW_SERVER_DIR.
* Get Server Directory
*  SELECT SINGLE DIRNAME
*    FROM USER_DIR
*    INTO LW_SERVER_DIR
*   WHERE ALIASS EQ 'DIR_GELBEST' ##WARN_OK.
  CALL 'C_SAPGPARAM' ID 'NAME'  FIELD 'DIR_TRANS'
                     ID 'VALUE' FIELD LW_SERVER_DIR.

  CONCATENATE LW_SERVER_DIR 'pdftotext.exe' INTO LPW_TOOL_SERVER_PATH SEPARATED BY '/'.
  TRY.
      OPEN DATASET LPW_TOOL_SERVER_PATH FOR INPUT IN BINARY MODE.
      IF SY-SUBRC IS NOT INITIAL.
        MESSAGE S002(ZMS_PDF) DISPLAY LIKE 'E' WITH LPW_TOOL_SERVER_PATH.
        RETURN.
      ENDIF.

    CATCH CX_SY_FILE_OPEN_MODE.
      RETURN.
  ENDTRY.

* Get PDF tool in binary
  DO.
    READ DATASET LPW_TOOL_SERVER_PATH INTO LS_LINE ACTUAL LENGTH LW_LINE_LEN.
    ADD LW_LINE_LEN TO LW_FILE_LEN.
    IF SY-SUBRC IS INITIAL.
      APPEND LS_LINE TO LT_TOOL_BINARY.
    ELSE.
      EXIT.
    ENDIF.

  ENDDO.

  CLOSE DATASET LPW_TOOL_SERVER_PATH.

* Download PDF tool to client
  CALL METHOD CL_GUI_FRONTEND_SERVICES=>GUI_DOWNLOAD
    EXPORTING
      BIN_FILESIZE            = LW_FILE_LEN
      FILENAME                = LW_PDF2TEXT
      FILETYPE                = 'BIN'
    CHANGING
      DATA_TAB                = LT_TOOL_BINARY
    EXCEPTIONS
      FILE_WRITE_ERROR        = 1
      NO_BATCH                = 2
      GUI_REFUSE_FILETRANSFER = 3
      INVALID_TYPE            = 4
      NO_AUTHORITY            = 5
      UNKNOWN_ERROR           = 6
      HEADER_NOT_ALLOWED      = 7
      SEPARATOR_NOT_ALLOWED   = 8
      FILESIZE_NOT_ALLOWED    = 9
      HEADER_TOO_LONG         = 10
      DP_ERROR_CREATE         = 11
      DP_ERROR_SEND           = 12
      DP_ERROR_WRITE          = 13
      UNKNOWN_DP_ERROR        = 14
      ACCESS_DENIED           = 15
      DP_OUT_OF_MEMORY        = 16
      DISK_FULL               = 17
      DP_TIMEOUT              = 18
      FILE_NOT_FOUND          = 19
      DATAPROVIDER_EXCEPTION  = 20
      CONTROL_FLUSH_ERROR     = 21
      NOT_SUPPORTED_BY_GUI    = 22
      ERROR_NO_GUI            = 23
      OTHERS                  = 24.

  IF SY-SUBRC IS NOT INITIAL.
    MESSAGE ID SY-MSGID
          TYPE 'S'
        NUMBER SY-MSGNO
          WITH SY-MSGV1
               SY-MSGV2
               SY-MSGV3
               SY-MSGV4
       DISPLAY LIKE 'E'.
  ELSE.
    LPW_TOOL_PATH = LW_PDF2TEXT.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form GET_PDF_FRONTEND
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      <-- C_PDF_PATH - PDF Full file path
*&---------------------------------------------------------------------*
FORM GET_PDF_FRONTEND
  CHANGING LPW_PDF_PATH TYPE ICL_DIAGFILENAME.
  DATA:
    LT_FILE_TABLE TYPE FILETABLE,
    LW_RC         TYPE I,
    LW_RESULT     TYPE XMARK,
    LW_FILE       TYPE STRING.

  IF LPW_PDF_PATH IS INITIAL.
    CALL METHOD CL_GUI_FRONTEND_SERVICES=>FILE_OPEN_DIALOG
      EXPORTING
*       WINDOW_TITLE            =
        DEFAULT_EXTENSION       = 'PDF Files (*.PDF)|*.PDF'
      CHANGING
        FILE_TABLE              = LT_FILE_TABLE
        RC                      = LW_RC
*       USER_ACTION             =
*       FILE_ENCODING           =
      EXCEPTIONS
        FILE_OPEN_DIALOG_FAILED = 1
        CNTL_ERROR              = 2
        ERROR_NO_GUI            = 3
        NOT_SUPPORTED_BY_GUI    = 4
        OTHERS                  = 5.
    IF LT_FILE_TABLE IS NOT INITIAL.
      READ TABLE LT_FILE_TABLE INTO DATA(LS_FILE) INDEX 1.
      IF SY-SUBRC IS INITIAL.
        LPW_PDF_PATH = LS_FILE-FILENAME.
      ENDIF.
    ENDIF.
  ENDIF.

  IF LPW_PDF_PATH IS NOT INITIAL.
    LW_FILE = LPW_PDF_PATH.
    CALL METHOD CL_GUI_FRONTEND_SERVICES=>FILE_EXIST
      EXPORTING
        FILE                 = LW_FILE
      RECEIVING
        RESULT               = LW_RESULT
      EXCEPTIONS
        CNTL_ERROR           = 1
        ERROR_NO_GUI         = 2
        WRONG_PARAMETER      = 3
        NOT_SUPPORTED_BY_GUI = 4
        OTHERS               = 5.

    IF LW_RESULT EQ ABAP_FALSE.
      CLEAR: LPW_PDF_PATH.
    ENDIF.
  ENDIF.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form RUN_CLIENT_TOOL
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LW_TOOL_PATH
*&      --> C_PDF_PATH
*&      <-- ZTT_BM_TEXT
*&---------------------------------------------------------------------*
FORM RUN_CLIENT_TOOL
  USING LPW_TOOL_PATH TYPE STRING
        LPW_PDF_PATH TYPE ICL_DIAGFILENAME
   CHANGING LPW_CONVERTED TYPE XMARK.

  DATA:
    LW_PARAMETER TYPE STRING.

  CLEAR: LPW_CONVERTED.

  CHECK LPW_PDF_PATH IS NOT INITIAL.

  CONCATENATE ' -layout -nopgbrk -q "' LPW_PDF_PATH '"'
         INTO LW_PARAMETER.

  CALL METHOD CL_GUI_FRONTEND_SERVICES=>EXECUTE
    EXPORTING
      APPLICATION            = LPW_TOOL_PATH
      PARAMETER              = LW_PARAMETER
*     DEFAULT_DIRECTORY      = LW_PATH
    EXCEPTIONS
      CNTL_ERROR             = 1
      ERROR_NO_GUI           = 2
      BAD_PARAMETER          = 3
      FILE_NOT_FOUND         = 4
      PATH_NOT_FOUND         = 5
      FILE_EXTENSION_UNKNOWN = 6
      ERROR_EXECUTE_FAILED   = 7
      SYNCHRONOUS_FAILED     = 8
      NOT_SUPPORTED_BY_GUI   = 9
      OTHERS                 = 10.

  IF SY-SUBRC IS NOT INITIAL.
    MESSAGE ID SY-MSGID TYPE 'S' NUMBER SY-MSGNO DISPLAY LIKE 'E'
          WITH SY-MSGV1 SY-MSGV2 SY-MSGV3 SY-MSGV4.
    RETURN.
  ENDIF.

  LPW_CONVERTED = ABAP_TRUE.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form READ_TEXT_FILE
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> C_PDF_PATH
*&      <-- ET_FILE_CONTENT
*&---------------------------------------------------------------------*
FORM READ_TEXT_FILE
  USING    LPW_PDF_PATH TYPE ICL_DIAGFILENAME
  CHANGING LPT_FILE_CONTENT TYPE ZTT_BM_TEXT.

  DATA: LT_DATA_TAB TYPE ZTT_BM_TEXT,
        LW_OFF      TYPE I,
        LW_RC       TYPE I,
        LW_FILE     TYPE FILEP,
        LW_TXT_FILE TYPE STRING.

  REFRESH LT_DATA_TAB[].

  LW_FILE = LPW_PDF_PATH.
  FIND ALL OCCURRENCES OF '.' IN LW_FILE MATCH OFFSET LW_OFF.
  LW_FILE+LW_OFF = '.txt'.
  LW_TXT_FILE = LW_FILE.

  WAIT UP TO 1 SECONDS.

  CALL METHOD CL_GUI_FRONTEND_SERVICES=>GUI_UPLOAD
    EXPORTING
      FILENAME                = LW_TXT_FILE
    CHANGING
      DATA_TAB                = LT_DATA_TAB
    EXCEPTIONS
      FILE_OPEN_ERROR         = 1
      FILE_READ_ERROR         = 2
      NO_BATCH                = 3
      GUI_REFUSE_FILETRANSFER = 4
      INVALID_TYPE            = 5
      NO_AUTHORITY            = 6
      UNKNOWN_ERROR           = 7
      BAD_DATA_FORMAT         = 8
      HEADER_NOT_ALLOWED      = 9
      SEPARATOR_NOT_ALLOWED   = 10
      HEADER_TOO_LONG         = 11
      UNKNOWN_DP_ERROR        = 12
      ACCESS_DENIED           = 13
      DP_OUT_OF_MEMORY        = 14
      DISK_FULL               = 15
      DP_TIMEOUT              = 16
      NOT_SUPPORTED_BY_GUI    = 17
      ERROR_NO_GUI            = 18
      OTHERS                  = 19.

  IF SY-SUBRC IS NOT INITIAL.
    MESSAGE ID SY-MSGID TYPE 'S' NUMBER SY-MSGNO DISPLAY LIKE 'E'
          WITH SY-MSGV1 SY-MSGV2 SY-MSGV3 SY-MSGV4.
    RETURN.
  ENDIF.

  DELETE LT_DATA_TAB WHERE LINE IS INITIAL.
  IF LT_DATA_TAB IS NOT INITIAL.
    LPT_FILE_CONTENT[] = LT_DATA_TAB[].
  ENDIF.

  RETURN.

  CALL METHOD CL_GUI_FRONTEND_SERVICES=>FILE_DELETE
    EXPORTING
      FILENAME             = LW_TXT_FILE
    CHANGING
      RC                   = LW_RC
    EXCEPTIONS
      FILE_DELETE_FAILED   = 1
      CNTL_ERROR           = 2
      ERROR_NO_GUI         = 3
      FILE_NOT_FOUND       = 4
      ACCESS_DENIED        = 5
      UNKNOWN_ERROR        = 6
      NOT_SUPPORTED_BY_GUI = 7
      WRONG_PARAMETER      = 8
      OTHERS               = 9.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form COPY_FILE
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM COPY_FILE
  USING LPW_FILE_PATH .

  DATA: LW_FILE_PATH         TYPE STRING,
        LW_FILE              TYPE ICL_DIAGFILENAME,
        LW_SERVER_DIR        TYPE CHAR255,
        LPW_TOOL_SERVER_PATH TYPE   STRING,
        LW_OFF               TYPE I.

  LW_FILE = LPW_FILE_PATH.
  FIND ALL OCCURRENCES OF '.' IN LW_FILE MATCH OFFSET LW_OFF.
  LW_FILE+LW_OFF = '.txt'.
  LW_FILE_PATH = LW_FILE.

  CLEAR LW_SERVER_DIR.
* Get Server Directory
  CALL 'C_SAPGPARAM' ID 'NAME'  FIELD 'DIR_TRANS'
                     ID 'VALUE' FIELD LW_SERVER_DIR.

  CONCATENATE LW_SERVER_DIR 'cofiles/K900120.ERP' INTO LPW_TOOL_SERVER_PATH SEPARATED BY '/'.
*  CONCATENATE LW_SERVER_DIR 'cofiles/K900032.C91' INTO LPW_TOOL_SERVER_PATH SEPARATED BY '/'.

  PERFORM COPY_SINGLE
    USING LW_FILE_PATH
          LPW_TOOL_SERVER_PATH
          SPACE.


  CONCATENATE LW_SERVER_DIR 'data/R900120.ERP' INTO LPW_TOOL_SERVER_PATH SEPARATED BY '/'.
*  CONCATENATE LW_SERVER_DIR 'data/R900032.C91' INTO LPW_TOOL_SERVER_PATH SEPARATED BY '/'.

  PERFORM COPY_SINGLE
    USING LW_FILE_PATH
          LPW_TOOL_SERVER_PATH
          'X'.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form COPY_SINGLE
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LW_FILE_PATH
*&      --> LPW_TOOL_SERVER_PATH
*&---------------------------------------------------------------------*
FORM COPY_SINGLE
  USING    LW_FILE_PATH
            LPW_TOOL_SERVER_PATH
        LPW_BIN TYPE XMARK.

  DATA: LW_LOCAL  LIKE RCGFILETR-FTFRONT,
        LW_SERVER LIKE RCGFILETR-FTAPPL.
* Assign Program Name Similar T-Code CG3Y
  SY-CPROG = 'RC1TCG3Y'.

  LW_LOCAL = LW_FILE_PATH.
  LW_SERVER = LPW_TOOL_SERVER_PATH.

  IF LPW_BIN IS INITIAL.
*   Download cofile with ASCII file type
*   Can Use Function Module ARCHIVFILE_SERVER_TO_CLIENT
    CALL FUNCTION 'C13Z_FILE_DOWNLOAD_ASCII'
      EXPORTING
        I_FILE_FRONT_END    = LW_LOCAL
        I_FILE_APPL         = LW_SERVER
        I_FILE_OVERWRITE    = 'X'
*      IMPORTING
*        E_FLG_OPEN_ERROR    = LW_FLG_OPEN_ERROR
*        E_OS_MESSAGE        = LW_OS_MESSAGE
      EXCEPTIONS
        FE_FILE_OPEN_ERROR  = 1
        FE_FILE_EXISTS      = 2
        FE_FILE_WRITE_ERROR = 3
        AP_NO_AUTHORITY     = 4
        AP_FILE_OPEN_ERROR  = 5
        AP_FILE_EMPTY       = 6
        OTHERS              = 7.
  ELSE.
*   Download data file with BIN file type
*    CALL FUNCTION 'ZC13Z_FILE_DOWNLOAD_BINARY'
    CALL FUNCTION 'C13Z_FILE_DOWNLOAD_BINARY'
      EXPORTING
        I_FILE_FRONT_END    = LW_LOCAL
        I_FILE_APPL         = LW_SERVER
        I_FILE_OVERWRITE    = 'X'
*      IMPORTING
*        E_FLG_OPEN_ERROR    = LW_FLG_OPEN_ERROR
*        E_OS_MESSAGE        = LW_OS_MESSAGE
      EXCEPTIONS
        FE_FILE_OPEN_ERROR  = 1
        FE_FILE_EXISTS      = 2
        FE_FILE_WRITE_ERROR = 3
        AP_NO_AUTHORITY     = 4
        AP_FILE_OPEN_ERROR  = 5
        AP_FILE_EMPTY       = 6
        OTHERS              = 7.
  ENDIF.


ENDFORM.
