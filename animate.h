/*
 * Animation routines
 */

#ifndef _ANIMATE_H
#define _ANIMATE_H

/* Current code requires these to be leaked */
extern int Animating;
extern Bool AnimationActive;
extern Bool MaybeAnimate;
extern int AnimationSpeed;
extern struct timeval AnimateTimeout;


void StartAnimation(void);
void StopAnimation(void);
void SetAnimationSpeed(int speed);
void ModifyAnimationSpeed(int incr);
void TryToAnimate(void);

#endif /* _ANIMATE_H */
