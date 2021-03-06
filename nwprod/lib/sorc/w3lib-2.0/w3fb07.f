       SUBROUTINE W3FB07(XI,XJ,ALAT1,ALON1,DX,ALONV,ALAT,ALON)
C$$$   SUBPROGRAM  DOCUMENTATION  BLOCK
C
C SUBPROGRAM:  W3FB07        GRID COORDS TO LAT/LON FOR GRIB
C   PRGMMR: STACKPOLE        ORG: NMC42       DATE:88-04-05
C
C ABSTRACT: CONVERTS THE COORDINATES OF A LOCATION ON EARTH GIVEN IN A
C   GRID COORDINATE SYSTEM OVERLAID ON A POLAR STEREOGRAPHIC MAP PRO-
C   JECTION TRUE AT 60 DEGREES N OR S LATITUDE TO THE
C   NATURAL COORDINATE SYSTEM OF LATITUDE/LONGITUDE
C   W3FB07 IS THE REVERSE OF W3FB06.
C   USES GRIB SPECIFICATION OF THE LOCATION OF THE GRID
C
C PROGRAM HISTORY LOG:
C   88-01-01  ORIGINAL AUTHOR:  STACKPOLE, W/NMC42
C   90-04-12  R.E.JONES   CONVERT TO CRAY CFT77 FORTRAN
C
C USAGE:  CALL W3FB07(XI,XJ,ALAT1,ALON1,DX,ALONV,ALAT,ALON)
C   INPUT ARGUMENT LIST:
C     XI       - I COORDINATE OF THE POINT  REAL*4
C     XJ       - J COORDINATE OF THE POINT  REAL*4
C     ALAT1    - LATITUDE  OF LOWER LEFT POINT OF GRID (POINT 1,1)
C                LATITUDE <0 FOR SOUTHERN HEMISPHERE; REAL*4
C     ALON1    - LONGITUDE OF LOWER LEFT POINT OF GRID (POINT 1,1)
C                  EAST LONGITUDE USED THROUGHOUT; REAL*4
C     DX       - MESH LENGTH OF GRID IN METERS AT 60 DEG LAT
C                 MUST BE SET NEGATIVE IF USING
C                 SOUTHERN HEMISPHERE PROJECTION; REAL*4
C                   190500.0 LFM GRID,
C                   381000.0 NH PE GRID, -381000.0 SH PE GRID, ETC.
C     ALONV    - THE ORIENTATION OF THE GRID.  I.E.,
C                THE EAST LONGITUDE VALUE OF THE VERTICAL MERIDIAN
C                WHICH IS PARALLEL TO THE Y-AXIS (OR COLUMNS OF
C                THE GRID) ALONG WHICH LATITUDE INCREASES AS
C                THE Y-COORDINATE INCREASES.  REAL*4
C                   FOR EXAMPLE:
C                   255.0 FOR LFM GRID,
C                   280.0 NH PE GRID, 100.0 SH PE GRID, ETC.
C
C   OUTPUT ARGUMENT LIST:
C     ALAT     - LATITUDE IN DEGREES (NEGATIVE IN SOUTHERN HEMI.)
C     ALON     - EAST LONGITUDE IN DEGREES, REAL*4
C
C   REMARKS: FORMULAE AND NOTATION LOOSELY BASED ON HOKE, HAYES,
C     AND RENNINGER'S "MAP PROJECTIONS AND GRID SYSTEMS...", MARCH 1981
C     AFGWC/TN-79/003
C
C ATTRIBUTES:
C   LANGUAGE: CRAY CFT77 FORTRAN
C   MACHINE:  CRAY Y-MP8/832
C
C$$$
C
         DATA  RERTH /6.3712E+6/,PI/3.1416/
         DATA  SS60  /1.86603/
C
C        PRELIMINARY VARIABLES AND REDIFINITIONS
C
C        H = 1 FOR NORTHERN HEMISPHERE; = -1 FOR SOUTHERN
C
C        REFLON IS LONGITUDE UPON WHICH THE POSITIVE X-COORDINATE
C        DRAWN THROUGH THE POLE AND TO THE RIGHT LIES
C        ROTATED AROUND FROM ORIENTATION (Y-COORDINATE) LONGITUDE
C        DIFFERENTLY IN EACH HEMISPHERE
C
         IF (DX.LT.0) THEN
           H      = -1.0
           DXL    = -DX
           REFLON = ALONV - 90.0
         ELSE
           H      = 1.0
           DXL    = DX
           REFLON = ALONV - 270.0
         ENDIF
C
         RADPD  = PI    / 180.0
         DEGPRD = 180.0 / PI
         REBYDX = RERTH / DXL
C
C        RADIUS TO LOWER LEFT HAND (LL) CORNER
C
         ALA1 =  ALAT1 * RADPD
         RMLL = REBYDX * COS(ALA1) * SS60/(1. + H * SIN(ALA1))
C
C        USE LL POINT INFO TO LOCATE POLE POINT
C
         ALO1 = (ALON1 - REFLON) * RADPD
         POLEI = 1. - RMLL * COS(ALO1)
         POLEJ = 1. - H * RMLL * SIN(ALO1)
C
C        RADIUS TO THE I,J POINT (IN GRID UNITS)
C
         XX =  XI - POLEI
         YY = (XJ - POLEJ) * H
         R2 =  XX**2 + YY**2
C
C        NOW THE MAGIC FORMULAE
C
         IF (R2.EQ.0) THEN
           ALAT = H * 90.
           ALON = REFLON
         ELSE
           GI2    = (REBYDX * SS60)**2
           ALAT   = DEGPRD * H * ASIN((GI2 - R2)/(GI2 + R2))
           ARCCOS = ACOS(XX/SQRT(R2))
           IF (YY.GT.0) THEN
             ALON = REFLON + DEGPRD * ARCCOS
           ELSE
             ALON = REFLON - DEGPRD * ARCCOS
           ENDIF
         ENDIF
         IF (ALON.LT.0) ALON = ALON + 360.
C
      RETURN
      END
