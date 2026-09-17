import '@angular/compiler';
import { bootstrapApplication } from '@angular/platform-browser';
import { provideHttpClient } from '@angular/common/http';
import { ErrorHandler, provideZonelessChangeDetection } from '@angular/core';
import { provideRouter, withHashLocation, withViewTransitions } from '@angular/router';
import { AppComponent } from './src/app.component';
import { APP_ROUTES } from './src/app.routes';
import { GlobalErrorHandler } from './src/services/global-error-handler.service';
import { DATA_STORE } from './src/services/data-store';
import { FirestoreDataStore } from './src/services/firestore-data-store';

const loader = document.getElementById('app-loader');
const errorDisplay = document.getElementById('app-error');
const appRoot = document.querySelector('app-root') as HTMLElement;

function showApp() {
  if (loader) {
    loader.style.opacity = '0';
    // Hide the loader after the fade-out transition
    setTimeout(() => {
      if(loader) loader.style.display = 'none';
    }, 500);
  }
  if (appRoot) {
    // Make the app root visible by changing opacity
    appRoot.style.opacity = '1';
    appRoot.style.pointerEvents = 'auto';
  }
}

function showError() {
  if (loader) {
    loader.style.opacity = '0';
     // Hide the loader after the fade-out transition
    setTimeout(() => {
      if (loader) loader.style.display = 'none';
    }, 500);
  }
  if (errorDisplay) {
    // Make the error message visible
    errorDisplay.style.display = 'flex';
  }
}

// Global error handler for issues that occur after bootstrapping
window.onerror = function(message, source, lineno, colno, error) {
  console.error('A global error was caught:', {
    message,
    source,
    lineno,
    colno,
    error
  });
  showError();
  // Prevent the default browser error handling
  return true;
};

bootstrapApplication(AppComponent, {
  providers: [
    provideZonelessChangeDetection(),
    provideHttpClient(),
    provideRouter(APP_ROUTES, withHashLocation(), withViewTransitions({ skipInitialTransition: true })),
    { provide: DATA_STORE, useClass: FirestoreDataStore },
    { provide: ErrorHandler, useClass: GlobalErrorHandler }
  ]
})
.then(() => {
  console.log('Angular application bootstrapped successfully.');
  showApp();
})
.catch(err => {
  console.error('Angular bootstrap failed:', err);
  showError();
});
