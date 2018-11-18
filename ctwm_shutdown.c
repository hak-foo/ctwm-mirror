/*
 * Shutdown (/restart) bits
 */

#include "ctwm.h"

#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>

#include "animate.h"
#include "captive.h"
#include "colormaps.h"
#include "ctwm_atoms.h"
#include "ctwm_shutdown.h"
#include "screen.h"
#include "session.h"
#ifdef SOUNDS
# include "sound.h"
#endif
#include "otp.h"
#include "win_ops.h"
#include "win_utils.h"


static void Reborder(Time mytime);


/**
 * Put a window back where it should be if we don't (any longer) control
 * it.  Essentially cancels out the repositioning due to our frame and
 * decorations, and restores the original border it had before we put our
 * own on it.
 */
void
RestoreWithdrawnLocation(TwmWindow *tmp)
{
	XWindowChanges xwc;
	unsigned int bw;

	// If this window is "unmapped" by moving it way offscreen, and is in
	// that state, move it back onto the window.
	if(tmp->UnmapByMovingFarAway && !visible(tmp)) {
		XMoveWindow(dpy, tmp->frame, tmp->frame_x, tmp->frame_y);
	}

	// If it's squeezed, unsqueeze it.
	if(tmp->squeezed) {
		Squeeze(tmp);
	}

	// Look up geometry bits.  Failure means ???  Maybe the window
	// disappeared on us?
	if(XGetGeometry(dpy, tmp->w, &JunkRoot, &xwc.x, &xwc.y,
	                &JunkWidth, &JunkHeight, &bw, &JunkDepth)) {
		int gravx, gravy;
		unsigned int mask;

		// Get gravity bits to know how to move stuff around when we take
		// away the decorations.
		GetGravityOffsets(tmp, &gravx, &gravy);

		// Shift for stripping out the titlebar and 3d borders
		if(gravy < 0) {
			xwc.y -= tmp->title_height;
		}
		xwc.x += gravx * tmp->frame_bw3D;
		xwc.y += gravy * tmp->frame_bw3D;

		// If the window used to have a border size different from what
		// it has now (from us), restore the old.
		if(bw != tmp->old_bw) {
			int xoff, yoff;

			if(!Scr->ClientBorderWidth) {
				// We used BorderWidth
				xoff = gravx;
				yoff = gravy;
			}
			else {
				// We used the original
				xoff = 0;
				yoff = 0;
			}

			xwc.x -= (xoff + 1) * tmp->old_bw;
			xwc.y -= (yoff + 1) * tmp->old_bw;
		}

		// Strip out our 2d borders, if we had a size other than the
		// win's original.
		if(!Scr->ClientBorderWidth) {
			xwc.x += gravx * tmp->frame_bw;
			xwc.y += gravy * tmp->frame_bw;
		}


		// Now put together the adjustment.  We'll always be moving the
		// X/Y coords.
		mask = (CWX | CWY);
		// xwc.[xy] already set

		// May be changing the border.
		if(bw != tmp->old_bw) {
			xwc.border_width = tmp->old_bw;
			mask |= CWBorderWidth;
		}

#if 0
		if(tmp->vs) {
			xwc.x += tmp->vs->x;
			xwc.y += tmp->vs->y;
		}
#endif

		// If it's in a WindowBox, reparent it back up to our real root.
		if(tmp->winbox && tmp->winbox->twmwin && tmp->frame) {
			int xbox, ybox;
			unsigned int j_bw;
			if(XGetGeometry(dpy, tmp->frame, &JunkRoot, &xbox, &ybox,
			                &JunkWidth, &JunkHeight, &j_bw, &JunkDepth)) {
				ReparentWindow(dpy, tmp, WinWin, Scr->Root, xbox, ybox);
			}
		}

		// Do the move (and possibly reborder
		XConfigureWindow(dpy, tmp->w, mask, &xwc);

		// If it came with a pre-made icon window, hide it
		if(tmp->wmhints->flags & IconWindowHint) {
			XUnmapWindow(dpy, tmp->wmhints->icon_window);
		}
	}

	// Done
	return;
}


/**
 * Restore some window positions/etc in preparation for going away.
 */
static void
Reborder(Time mytime)
{
	TwmWindow *tmp;                     /* temp twm window structure */
	int scrnum;
	ScreenInfo *savedScreen;            /* Its better to avoid coredumps */

	/* put a border back around all windows */

	XGrabServer(dpy);
	savedScreen = Scr;
	for(scrnum = 0; scrnum < NumScreens; scrnum++) {
		if((Scr = ScreenList[scrnum]) == NULL) {
			continue;
		}

		InstallColormaps(0, &Scr->RootColormaps);       /* force reinstall */
		for(tmp = Scr->FirstWindow; tmp != NULL; tmp = tmp->next) {
			RestoreWithdrawnLocation(tmp);
			XMapWindow(dpy, tmp->w);
		}
	}
	Scr = savedScreen;
	XUngrabServer(dpy);
	SetFocus(NULL, mytime);
}


/**
 * Cleanup and exit twm
 */
void
Done(void)
{
#ifdef SOUNDS
	play_exit_sound();
#endif
	Reborder(CurrentTime);
#ifdef EWMH
	EwmhTerminate();
#endif /* EWMH */
	XDeleteProperty(dpy, Scr->Root, XA_WM_WORKSPACESLIST);
	if(CLarg.is_captive) {
		RemoveFromCaptiveList(Scr->captivename);
	}
	XCloseDisplay(dpy);
	exit(0);
}


/**
 * exec() ourself to restart.
 */
void
DoRestart(Time t)
{
	StopAnimation();
	XSync(dpy, 0);
	Reborder(t);
	XSync(dpy, 0);

	if(smcConn) {
		SmcCloseConnection(smcConn, 0, NULL);
	}

	fprintf(stderr, "%s:  restarting:  %s\n",
	        ProgramName, *Argv);
	execvp(*Argv, Argv);
	fprintf(stderr, "%s:  unable to restart:  %s\n", ProgramName, *Argv);
}
