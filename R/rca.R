#' Relevant Component Analysis
#'
#' Performs relevant component analysis on the given data.
#'
#' The RCA function takes a data set and a set of positive constraints
#' as arguments and returns a linear transformation of the data space
#' into better representation, alternatively, a Mahalanobis metric
#' over the data space.
#'
#' Relevant component analysis consists of three steps:
#' \enumerate{\item locate the test point
#' \item compute the distances between the test points
#' \item find \eqn{k} shortest distances and the bla}
#' The new representation is known to be optimal in an information
#' theoretic sense under a constraint of keeping equivalent data
#' points close to each other.
#'
#' @param x matrix or data frame of original data.
#'          Each row is a feature vector of a data instance.
#' @param chunks list of \code{k} numerical vectors.
#'               Each vector represents a chunklet, the elements
#'               in the vectors indicate where the samples locate
#'               in \code{x}. See examples for more information.
#'
#' @return list of the RCA results:
#' \item{B}{The RCA suggested Mahalanobis matrix.
#'          Distances between data points x1, x2 should be
#'          computed by (x2 - x1)' * B * (x2 - x1)}
#' \item{A}{The RCA suggested transformation of the data.
#'          The data should be transformed by A * data}
#' \item{newX}{The data after the RCA transformation (A).
#'             newData = A * data}
#'
#' The three returned argument are just different forms of the same output.
#' If one is interested in a Mahalanobis metric over the original data space,
#' the first argument is all she/he needs. If a transformation into another
#' space (where one can use the Euclidean metric) is preferred, the second
#' returned argument is sufficient. Using A and B is equivalent in the
#' following sense:
#'
#' if y1 = A * x1, y2 = A * y2  then
#' (x2 - x1)' * B * (x2 - x1) = (y2 - y1)' * (y2 - y1)
#'
#' @keywords rca transformation mahalanobis metric
#'
#' @aliases rca
#'
#' @note Note that any different sets of instances (chunklets),
#'       e.g. {1, 3, 7} and {4, 6}, might belong to the
#'       same class and might belong to different classes.
#'
#' @author Xiao Nan <\url{http://www.road2stat.com}>
#'
#' @seealso See \code{\link{dca}} for exploiting negative constrains.
#'
#' @export rca
#' @importFrom lfda %^%
#' @import MASS
#'
#' @references
#' Aharon Bar-Hillel, Tomer Hertz, Noam Shental, and Daphna Weinshall (2003).
#' Learning Distance Functions using Equivalence Relations.
#' \emph{Proceedings of 20th International Conference on
#' Machine Learning (ICML2003)}.
#'
#' @examples
#' \dontrun{
#' set.seed(1234)
#' require(MASS)  # generate synthetic Gaussian data
#' k = 100        # sample size of each class
#' n = 3          # specify how many class
#' N = k * n      # total sample number
#' x1 = mvrnorm(k, mu = c(-10, 6), matrix(c(10, 4, 4, 10), ncol = 2))
#' x2 = mvrnorm(k, mu = c(0, 0), matrix(c(10, 4, 4, 10), ncol = 2))
#' x3 = mvrnorm(k, mu = c(10, -6), matrix(c(10, 4, 4, 10), ncol = 2))
#' x = as.data.frame(rbind(x1, x2, x3))
#' x$V3 = gl(n, k)
#'
#' # The fully labeled data set with 3 classes
#' plot(x$V1, x$V2, bg = c("#E41A1C", "#377EB8", "#4DAF4A")[x$V3],
#'      pch = c(rep(22, k), rep(21, k), rep(25, k)))
#' Sys.sleep(3)
#'
#' # Same data unlabeled; clearly the classes' structure is less evident
#' plot(x$V1, x$V2)
#' Sys.sleep(3)
#'
#' chunk1 = sample(1:100, 5)
#' chunk2 = sample(setdiff(1:100, chunk1), 5)
#' chunk3 = sample(101:200, 5)
#' chunk4 = sample(setdiff(101:200, chunk3), 5)
#' chunk5 = sample(201:300, 5)
#' chks = x[c(chunk1, chunk2, chunk3, chunk4, chunk5), ]
#' chunks = list(chunk1, chunk2, chunk3, chunk4, chunk5)
#'
#' # The chunklets provided to the RCA algorithm
#' plot(chks$V1, chks$V2, col = rep(c("#E41A1C", "#377EB8",
#'      "#4DAF4A", "#984EA3", "#FF7F00"), each = 5),
#'      pch = rep(0:4, each = 5), ylim = c(-15, 15))
#' Sys.sleep(3)
#'
#' # Whitening transformation applied to the  chunklets
#' chkTransformed = as.matrix(chks[ , 1:2]) %*% rca(x[ , 1:2], chunks)$A
#'
#' plot(chkTransformed[ , 1], chkTransformed[ , 2], col = rep(c(
#'      "#E41A1C", "#377EB8", "#4DAF4A", "#984EA3", "#FF7F00"), each = 5),
#'      pch = rep(0:4, each = 5), ylim = c(-15, 15))
#' Sys.sleep(3)
#'
#' # The origin data after applying the RCA transformation
#' plot(rca(x[ , 1:2], chunks)$newX[, 1], rca(x[ , 1:2], chunks)$newX[, 2],
#'          bg = c("#E41A1C", "#377EB8", "#4DAF4A")[gl(n, k)],
#'          pch = c(rep(22, k), rep(21, k), rep(25, k)))
#'
#' # The RCA suggested transformation of the data, dimensionality reduced
#' rca(x[ , 1:2], chunks)$A
#'
#' # The RCA suggested Mahalanobis matrix
#' rca(x[ , 1:2], chunks)$B
#' }
#'
rca <- function(x, chunks) {

	chunkNum = length(chunks)
	chunkDf = vector("list", chunkNum)
	p = length(unlist(chunks))

	for (i in 1:chunkNum) {
		chunkDf[[i]] = as.matrix(x[chunks[[i]], ])
	}

	chunkMean = lapply(chunkDf, colMeans)

	for (i in 1:chunkNum) {
		chunkDf[[i]] = chunkDf[[i]] - chunkMean[[i]]
	}

	cData = do.call(rbind, chunkDf)  # calc inner covariance matrix and normalize
	innerCov = cov(cData) * ((nrow(cData) - 1) / nrow(cData))

	for (i in 1:chunkNum) {
		chunkDf[[i]] = t(chunkDf[[i]]) %*% chunkDf[[i]]
	}

	hatC = Reduce("+", chunkDf)/p    # Reduce() do the sum of matrices in a list

	B = solve(hatC)                  # raw mahalanobis metric

	A = diag(ncol(x))
	A = A %*% (innerCov %^% (-0.5))  # whitening transformation matrix

	newX = as.matrix(x) %*% A        # original data transformed

	return(list("B" = B, "A" = A, "newX" = newX))
}
