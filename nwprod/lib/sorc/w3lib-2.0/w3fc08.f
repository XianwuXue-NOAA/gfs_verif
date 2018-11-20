      SUBROUTINE W3FC08(FFID, FFJD, FU, FV, FGU, FGV)
C$$$  SUBPROGRAM DOCUMENTATION BLOCK
C                .      .    .                                       .
C SUBPROGRAM:  W3FC08        U-V COMPS FROM EARTH TO NORTH HEM GRID
C   PRGMMR: CHASE            ORG: NMC421      DATE:88-10-26
C
C ABSTRACT: GIVEN THE EARTH-ORIENTED WIND COMPONENTS ON A NORTHERN
C   HEMISPHERE POLAR STEREOGRAPHIC GRID POINT, COMPUTE THE GRID-
C   ORIENTED COMPONENTS AT THAT POINT.  INPUT WIND COMPONENTS AT THE
C   NORTH POLE POINT ARE ASSUMED TO CONFORM TO
C   THE 'WMO' STANDARDS FOR REPORTING WINDS AT THE NORTH POLE, WITH
C   THE OUTPUT COMPONENTS COMPUTED RELATIVE TO THE X-Y AXES ON THE
C   GRID.  (SEE OFFICE NOTE 241 FOR WMO DEFINITION.)
C
C PROGRAM HISTORY LOG:
C   81-12-30  STACKPOLE, J.
C   88-10-18  CHASE, P.   LET OUTPUT VARIABLES OVERLAY INPUT
C   91-03-06  R.E.JONES   CHANGE TO CRAY CFT77 FORTRAN
C
C USAGE:    CALL W3FC08 (FFID, FFJD, FU, FV, FGU, FGV)
C
C   INPUT ARGUMENT LIST:
C     FFID     - REAL   I-DISPLACEMENT FROM POINT TO NORTH POLE IN
C                GRID UNITS
C     FFJD     - REAL   J-DISPLACEMENT FROM POINT TO NORTH POLE IN
C                GRID UNITS
C     FU       - REAL   EARTH-ORIENTED U-COMPONENT, POSITIVE FROM WEST
C     FV       - REAL   EARTH-ORIENTED V-COMPONENT, POSITIVE FROM EAST
C
C   OUTPUT ARGUMENT LIST:
C     FGU      - REAL   GRID-ORIENTED U-COMPONENT.  MAY REFERENCE
C                SAME LOCATION AS FU.
C     FGV      - REAL   GRID-ORIENTED V-COMPONENT.  MAY REFERENCE
C                SAME LOCATION AS FV.
C
C   INPUT FILES:   NONE
C
C   OUTPUT FILES:  NONE
C
C   SUBPROGRAMS CALLED:
C     LIBRARY:
C       COMMON   - SQRT
C
C REMARKS:  FFID AND FFJD MAY BE CALCULATED AS FOLLOWS.....
C     FFID = REAL(IP - I)
C     FFJD = REAL(JP - J)
C   WHERE (IP, JP) ARE THE GRID COORDINATES OF THE NORTH POLE AND
C   (I,J) ARE THE GRID COORDINATES OF THE POINT.
C
C ATTRIBUTES:
C   LANGUAGE: CRAY CFT77 FORTRAN
C   MACHINE:  CRAY C916-128, CRAY Y-MP8/864, CRAY Y-MP EL2/256
C
C$$$
C
      SAVE
C
      DATA  COS280/  0.1736482 /
      DATA  SIN280/ -0.9848078 /
C
C     COS280 AND SIN280 ARE FOR WIND AT POLE
C     (USED FOR CO-ORDINATE ROTATION TO GRID ORIENTATION)
C
      DFP = SQRT(FFID * FFID + FFJD * FFJD)
      IF (DFP .EQ. 0.) THEN
        XFGU = -(FU * COS280 + FV * SIN280)
        FGV  = -(FV * COS280 - FU * SIN280)
      ELSE
        XFGU = (FU * FFJD + FV * FFID) / DFP
        FGV  = (FV * FFJD - FU * FFID) / DFP
      ENDIF
      FGU = XFGU
      RETURN
      END
